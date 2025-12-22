import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fruit_quality_detector/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum AnalysisStep {
  none,
  preprocessing,
  detectingFruit,
  analyzingRipeness,
  checkingDisease,
  completed,
}

class AnalysisHistory {
  final String imagePath;
  final String fruitType;
  final String ripeness;
  final String disease;
  final DateTime timestamp;

  AnalysisHistory({
    required this.imagePath,
    required this.fruitType,
    required this.ripeness,
    required this.disease,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'fruitType': fruitType,
    'ripeness': ripeness,
    'disease': disease,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AnalysisHistory.fromJson(Map<String, dynamic> json) =>
      AnalysisHistory(
        imagePath: json['imagePath'],
        fruitType: json['fruitType'],
        ripeness: json['ripeness'],
        disease: json['disease'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();
  File? _image;
  String _fruitResult = '';
  String _ripenessResult = '';
  String _diseaseResult = '';
  bool _loading = false;
  AnalysisStep _currentStep = AnalysisStep.none;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  List<AnalysisHistory> _history = [];

  Interpreter? _fruitInterpreter;
  Interpreter? _ripenessInterpreter;
  Interpreter? _diseaseInterpreter;

  List<String>? _fruitLabels;
  List<String>? _ripenessLabels;
  List<String>? _diseaseLabels;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadModels();
    _loadHistory();
  }

  String get _historyStorageKey {
    final uid = _authService.currentUser?.uid;
    return uid == null ? 'analysis_history_anon' : 'analysis_history_$uid';
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // One-time migration from the pre-auth single-user key.
    // If your app previously stored history without auth, this moves it into the
    // currently authenticated user's bucket on first login.
    const legacyKey = 'analysis_history';
    final hasUserHistory = prefs.containsKey(_historyStorageKey);
    if (!hasUserHistory && prefs.containsKey(legacyKey)) {
      final legacy = prefs.getStringList(legacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        await prefs.setStringList(_historyStorageKey, legacy);
      }
      await prefs.remove(legacyKey);
    }

    final historyJson = prefs.getStringList(_historyStorageKey) ?? [];
    setState(() {
      _history = historyJson
          .map((json) => AnalysisHistory.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _saveToHistory() async {
    final history = AnalysisHistory(
      imagePath: _image!.path,
      fruitType: _formatFruitName(_fruitResult),
      ripeness: _formatRipenessName(_ripenessResult),
      disease: _formatDiseaseName(_diseaseResult),
      timestamp: DateTime.now(),
    );

    _history.insert(0, history);
    if (_history.length > 50) {
      _history = _history.sublist(0, 50);
    }

    final prefs = await SharedPreferences.getInstance();
    final historyJson = _history.map((h) => jsonEncode(h.toJson())).toList();
    await prefs.setStringList(_historyStorageKey, historyJson);
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } catch (_) {
      // Intentionally hide error messages from the UI.
    }
  }

  String _formatFruitName(String rawName) {
    // Convert robotic names like "Rot_Apple", "Pear 1", "Rottenapples" to clean names
    String name = rawName.trim();

    // Remove common disease/quality prefixes
    name = name.replaceAll(
      RegExp(r'^(Rot_|Rotten_?|Fresh_?|Bad_?|Good_?)', caseSensitive: false),
      '',
    );

    // Remove numbers and extra spaces
    name = name.replaceAll(RegExp(r'\d+'), '').trim();

    // Replace underscores with spaces
    name = name.replaceAll('_', ' ');

    // Remove extra spaces
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize first letter of each word
    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _formatRipenessName(String rawName) {
    String name = rawName.trim().toLowerCase();

    // Handle various ripeness formats
    if (name.contains('ripe') &&
        !name.contains('unripe') &&
        !name.contains('over')) {
      return 'Ripe';
    } else if (name.contains('unripe')) {
      return 'Unripe';
    } else if (name.contains('over')) {
      return 'Overripe';
    }

    // Remove numbers and clean up
    name = name.replaceAll(RegExp(r'\d+'), '').trim();
    name = name.replaceAll('_', ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _formatDiseaseName(String rawName) {
    String name = rawName.trim();

    // Check if healthy (various formats)
    if (name == '0' ||
        name.toLowerCase().contains('healthy') ||
        name.toLowerCase().contains('no disease') ||
        name.toLowerCase() == 'fresh') {
      return 'Healthy';
    }

    // Check for common disease patterns
    String nameLower = name.toLowerCase();
    if (nameLower.contains('rot')) {
      return 'Showing Signs of Rot';
    } else if (nameLower.contains('scab')) {
      return 'Apple Scab Detected';
    } else if (nameLower.contains('rust')) {
      return 'Rust Disease';
    } else if (nameLower.contains('spot')) {
      return 'Spot Disease';
    } else if (nameLower.contains('mold')) {
      return 'Mold Detected';
    }

    // Remove numbers and clean up
    name = name.replaceAll(RegExp(r'\d+'), '').trim();
    name = name.replaceAll('_', ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize properly
    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _fruitInterpreter?.close();
    _ripenessInterpreter?.close();
    _diseaseInterpreter?.close();
    super.dispose();
  }

  Future<void> _loadModels() async {
    _fruitInterpreter = await Interpreter.fromAsset(
      'assets/fruit-classifier.tflite',
    );
    _ripenessInterpreter = await Interpreter.fromAsset(
      'assets/ripeness_model.tflite',
    );
    _diseaseInterpreter = await Interpreter.fromAsset(
      'assets/disease_classifier.tflite',
    );

    _fruitLabels = (await DefaultAssetBundle.of(
      context,
    ).loadString('assets/fruit-classifier-labels.txt')).split('\n');
    _ripenessLabels = (await DefaultAssetBundle.of(
      context,
    ).loadString('assets/ripeness_labels.txt')).split('\n');
    _diseaseLabels = (await DefaultAssetBundle.of(
      context,
    ).loadString('assets/disease_classifier.txt')).split('\n');
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _image = File(image.path);
        _loading = true;
        _fruitResult = '';
        _ripenessResult = '';
        _diseaseResult = '';
        _currentStep = AnalysisStep.preprocessing;
      });
      await _runInference();
    }
  }

  Future<void> _runInference() async {
    if (_image == null ||
        _fruitInterpreter == null ||
        _ripenessInterpreter == null ||
        _diseaseInterpreter == null) {
      return;
    }

    // Step 1: Preprocessing
    setState(() => _currentStep = AnalysisStep.preprocessing);
    await Future.delayed(const Duration(milliseconds: 800));

    // Step 2: Fruit classification
    setState(() => _currentStep = AnalysisStep.detectingFruit);
    var fruitInput = _preprocessImage(_image!, 224);
    var fruitOutput = List.filled(
      1 * _fruitLabels!.length,
      0,
    ).reshape([1, _fruitLabels!.length]);
    _fruitInterpreter!.run(fruitInput, fruitOutput);
    var fruitResultIndex = _getIndexOfMax(fruitOutput[0]);
    _fruitResult = _fruitLabels![fruitResultIndex];
    await Future.delayed(const Duration(milliseconds: 800));

    // Step 3: Ripeness detection
    setState(() => _currentStep = AnalysisStep.analyzingRipeness);
    var ripenessInput = _preprocessImage(_image!, 224);
    var ripenessOutput = List.filled(
      1 * _ripenessLabels!.length,
      0,
    ).reshape([1, _ripenessLabels!.length]);
    _ripenessInterpreter!.run(ripenessInput, ripenessOutput);
    var ripenessResultIndex = _getIndexOfMax(ripenessOutput[0]);
    _ripenessResult = _ripenessLabels![ripenessResultIndex];
    await Future.delayed(const Duration(milliseconds: 800));

    // Step 4: Disease classification
    setState(() => _currentStep = AnalysisStep.checkingDisease);
    var diseaseInput = _preprocessImage(_image!, 224);
    var diseaseOutput = List.filled(
      1 * _diseaseLabels!.length,
      0,
    ).reshape([1, _diseaseLabels!.length]);
    _diseaseInterpreter!.run(diseaseInput, diseaseOutput);
    var diseaseResultIndex = _getIndexOfMax(diseaseOutput[0]);
    _diseaseResult = _diseaseLabels![diseaseResultIndex];
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _currentStep = AnalysisStep.completed;
      _loading = false;
    });

    // Save to history
    await _saveToHistory();

    // Navigate to results page
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ResultsPage(
            image: _image!,
            fruitType: _formatFruitName(_fruitResult),
            ripeness: _formatRipenessName(_ripenessResult),
            disease: _formatDiseaseName(_diseaseResult),
          ),
        ),
      );
    }
  }

  dynamic _preprocessImage(File image, int size) {
    var imageBytes = image.readAsBytesSync();
    img.Image? originalImage = img.decodeImage(imageBytes);
    img.Image resizedImage = img.copyResize(
      originalImage!,
      width: size,
      height: size,
    );

    var buffer = List.generate(
      1,
      (i) => List.generate(
        size,
        (j) => List.generate(size, (k) => List.filled(3, 0.0)),
      ),
    );

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        var pixel = resizedImage.getPixel(x, y);
        buffer[0][y][x][0] = pixel.r / 255.0;
        buffer[0][y][x][1] = pixel.g / 255.0;
        buffer[0][y][x][2] = pixel.b / 255.0;
      }
    }
    return buffer;
  }

  int _getIndexOfMax(List<dynamic> list) {
    int maxIndex = 0;
    for (int i = 1; i < list.length; i++) {
      if (list[i] > list[maxIndex]) {
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1a237e),
              const Color(0xFF0d47a1),
              const Color(0xFF01579b),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isShortScreen = constraints.maxHeight < 740;

              final uploadCard = Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showPicker(context),
                        borderRadius: BorderRadius.circular(30),
                        child: Builder(
                          builder: (context) {
                            final screenHeight = MediaQuery.sizeOf(
                              context,
                            ).height;
                            final isVeryShort = screenHeight < 720;

                            final outerPadding = isVeryShort ? 20.0 : 48.0;
                            final bubblePadding = isVeryShort ? 16.0 : 24.0;
                            final iconSize = isVeryShort ? 56.0 : 80.0;
                            final titleFontSize = isVeryShort ? 18.0 : 24.0;
                            final subtitleFontSize = isVeryShort ? 12.0 : 14.0;
                            final gapLarge = isVeryShort ? 12.0 : 24.0;
                            final gapSmall = isVeryShort ? 8.0 : 12.0;

                            return Padding(
                              padding: EdgeInsets.all(outerPadding),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(bubblePadding),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: iconSize,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: gapLarge),
                                  Text(
                                    'Upload Fruit Image',
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );

              final content = Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Header with History Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          tooltip: 'Sign out',
                          onPressed: _signOut,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.history,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    HistoryPage(history: _history),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Title Section
                    Text(
                      'Fruit Quality',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Detector',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        color: Colors.white70,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Upload Area
                    if (isShortScreen)
                      uploadCard
                    else
                      Expanded(child: uploadCard),

                    // Features Section
                    const SizedBox(height: 40),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildFeatureChip('Fruit Type', Icons.apple),
                        _buildFeatureChip('Ripeness', Icons.eco),
                        _buildFeatureChip('Disease', Icons.healing),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );

              if (!isShortScreen) {
                return content;
              }

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: content,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1a237e),
              const Color(0xFF0d47a1),
              const Color(0xFF01579b),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image Preview
                if (_image != null)
                  Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    ),
                  ),
                const SizedBox(height: 60),

                // Loading Animation
                RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      gradient: SweepGradient(
                        colors: [Colors.transparent, Colors.white],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Analysis Steps
                Text(
                  'Analyzing Image',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                _buildStepIndicator(
                  'Preprocessing Image',
                  Icons.image_outlined,
                  AnalysisStep.preprocessing,
                ),
                _buildStepIndicator(
                  'Detecting Fruit Type',
                  Icons.search,
                  AnalysisStep.detectingFruit,
                ),
                _buildStepIndicator(
                  'Analyzing Ripeness',
                  Icons.analytics_outlined,
                  AnalysisStep.analyzingRipeness,
                ),
                _buildStepIndicator(
                  'Checking for Diseases',
                  Icons.health_and_safety_outlined,
                  AnalysisStep.checkingDisease,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(String label, IconData icon, AnalysisStep step) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep.index > step.index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green
                  : isActive
                  ? Colors.white
                  : Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: isCompleted
                  ? Colors.white
                  : isActive
                  ? const Color(0xFF0d47a1)
                  : Colors.white.withOpacity(0.5),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isActive || isCompleted
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isActive)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// Results Page with detailed explanations
class ResultsPage extends StatelessWidget {
  final File image;
  final String fruitType;
  final String ripeness;
  final String disease;

  const ResultsPage({
    super.key,
    required this.image,
    required this.fruitType,
    required this.ripeness,
    required this.disease,
  });

  String _getFruitDescription(String fruit) {
    final fruitLower = fruit.toLowerCase().trim();
    final descriptions = {
      'apple':
          'Apples are one of the most widely consumed fruits globally. Rich in fiber, vitamin C, and various antioxidants, they support heart health and aid digestion. A medium apple provides about 95 calories and helps maintain healthy cholesterol levels.',
      'banana':
          'Bananas are an excellent source of potassium, vitamin B6, and fiber. They provide quick energy and help maintain healthy blood pressure levels. Rich in natural sugars, they make a perfect pre or post-workout snack.',
      'orange':
          'Oranges are citrus fruits packed with vitamin C, fiber, and antioxidants. They boost immune system function and promote healthy skin. One orange provides over 100% of your daily vitamin C requirement.',
      'mango':
          'Mangoes are tropical fruits rich in vitamins A and C, fiber, and antioxidants. They support immune function and may improve digestive health. Known as the "king of fruits," mangoes are also high in folate and beneficial plant compounds.',
      'strawberry':
          'Strawberries are nutrient-rich berries loaded with vitamin C, manganese, and antioxidants. They may improve heart health and blood sugar control. These low-calorie fruits are also rich in folate and potassium.',
      'grape':
          'Grapes contain antioxidants, especially resveratrol, which may benefit heart health. They\'re also a good source of vitamin K and copper. Both red and green varieties offer health benefits and natural sweetness.',
      'watermelon':
          'Watermelon is a hydrating fruit (92% water) rich in vitamins A and C, as well as the antioxidant lycopene. It may reduce inflammation and improve heart health while being low in calories.',
      'pineapple':
          'Pineapples contain bromelain, an enzyme that may aid digestion and reduce inflammation. They\'re also rich in vitamin C, manganese, and antioxidants. This tropical fruit supports immune function and bone health.',
      'pear':
          'Pears are an excellent source of dietary fiber, vitamin C, and copper. They support digestive health and may help with weight management. Their natural sweetness and smooth texture make them a popular choice for all ages.',
      'peach':
          'Peaches are stone fruits rich in vitamins A and C, potassium, and fiber. They support skin health, digestion, and immune function. Low in calories, they make a refreshing and nutritious snack.',
      'plum':
          'Plums are packed with antioxidants, vitamins, and minerals. They support bone health, aid digestion, and may help reduce the risk of chronic diseases. Both fresh and dried plums (prunes) offer significant health benefits.',
      'cherry':
          'Cherries are rich in antioxidants and anti-inflammatory compounds. They may improve sleep quality, reduce muscle pain, and support heart health. These small fruits pack a powerful nutritional punch.',
      'kiwi':
          'Kiwis are exceptionally high in vitamin C, even more than oranges. They support immune function, aid digestion, and promote healthy skin. The fuzzy exterior protects a vibrant green interior full of nutrients.',
      'lemon':
          'Lemons are citrus fruits extremely high in vitamin C. They support immune health, aid digestion, and help with iron absorption. Their acidic nature also makes them excellent for flavoring and preserving foods.',
      'lime':
          'Limes are citrus fruits rich in vitamin C and antioxidants. They boost immunity, improve heart health, and aid in iron absorption. Their distinct tartness is used in cuisines worldwide.',
      'tomato':
          'Tomatoes are technically fruits rich in lycopene, vitamin C, and potassium. They support heart health, reduce cancer risk, and promote healthy skin. Both raw and cooked tomatoes offer significant health benefits.',
    };

    for (var key in descriptions.keys) {
      if (fruitLower.contains(key)) {
        return descriptions[key]!;
      }
    }

    return 'This nutritious fruit provides essential vitamins, minerals, and beneficial plant compounds that support overall health and wellness. Fruits are an important part of a balanced diet and offer natural energy and fiber.';
  }

  String _getRipenessExplanation(String ripeness) {
    final ripenessLower = ripeness.toLowerCase().trim();

    if (ripenessLower.contains('ripe') &&
        !ripenessLower.contains('unripe') &&
        !ripenessLower.contains('over')) {
      return 'Perfect for consumption! This fruit is at its optimal ripeness level with the best flavor, texture, and nutritional value. The sugars are fully developed, making it sweet and delicious. Consume within 1-2 days for best quality.';
    } else if (ripenessLower.contains('unripe')) {
      return 'Not yet ready for optimal consumption. This fruit needs more time to develop its full flavor and sweetness. Store at room temperature for a few days to allow it to ripen naturally. Unripe fruits can be harder and more acidic.';
    } else if (ripenessLower.contains('over')) {
      return 'Past its prime ripeness. While still edible, this fruit may have a softer texture and less optimal flavor. It\'s best used quickly, ideally in smoothies, baking, or cooking where the texture change is less noticeable. Check for any spoilage before consuming.';
    }

    return 'The ripeness level has been analyzed. Check the fruit\'s firmness, color, and smell to confirm its readiness for consumption.';
  }

  String _getDiseaseExplanation(String disease) {
    final diseaseLower = disease.toLowerCase().trim();

    if (diseaseLower.contains('healthy') ||
        diseaseLower.contains('no disease') ||
        diseaseLower == '0') {
      return 'Excellent news! No signs of disease detected. This fruit appears healthy with no visible symptoms of fungal, bacterial, or viral infections. The fruit is safe for consumption and should maintain good quality if stored properly.';
    } else if (diseaseLower.contains('scab')) {
      return 'Apple scab detected. This is a fungal disease causing dark, rough spots on the fruit surface. While it affects appearance and may reduce storage life, the fruit is generally still safe to eat if you remove affected areas. Wash thoroughly before consumption.';
    } else if (diseaseLower.contains('rot')) {
      return 'Signs of rot detected. This indicates fungal or bacterial breakdown of fruit tissue. Affected areas should be removed before consumption. If the rot is extensive, it\'s best to discard the fruit to avoid potential health risks.';
    } else if (diseaseLower.contains('rust')) {
      return 'Rust disease detected. This fungal infection causes orange or brown spots. While mainly cosmetic, it can affect flavor and texture. Remove affected areas and consume the rest of the fruit promptly.';
    } else if (diseaseLower.contains('black spot') ||
        diseaseLower.contains('spot')) {
      return 'Spot disease detected. These are typically fungal infections causing discolored patches. The fruit is often still edible if you cut away the affected spots, but flavor may be compromised.';
    }

    return 'Disease analysis completed. Examine the fruit carefully for any unusual discoloration, soft spots, or unusual odors before consumption. When in doubt, it\'s best to err on the side of caution.';
  }

  Color _getRipenessColor(String ripeness) {
    final ripenessLower = ripeness.toLowerCase().trim();
    if (ripenessLower.contains('ripe') &&
        !ripenessLower.contains('unripe') &&
        !ripenessLower.contains('over')) {
      return Colors.green;
    } else if (ripenessLower.contains('unripe')) {
      return Colors.orange;
    } else if (ripenessLower.contains('over')) {
      return Colors.red;
    }
    return Colors.blue;
  }

  Color _getDiseaseColor(String disease) {
    final diseaseLower = disease.toLowerCase().trim();
    if (diseaseLower.contains('healthy') ||
        diseaseLower.contains('no disease') ||
        diseaseLower == '0') {
      return Colors.green;
    }
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1a237e),
              const Color(0xFF0d47a1),
              const Color(0xFF01579b),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Analysis Results',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image
                      Hero(
                        tag: 'fruit_image',
                        child: Container(
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(image, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Fruit Type Card
                      _buildResultCard(
                        context,
                        'Fruit Identification',
                        fruitType.trim(),
                        _getFruitDescription(fruitType),
                        Icons.apple,
                        Colors.purple,
                      ),
                      const SizedBox(height: 16),

                      // Ripeness Card
                      _buildResultCard(
                        context,
                        'Ripeness Analysis',
                        ripeness.trim(),
                        _getRipenessExplanation(ripeness),
                        Icons.eco,
                        _getRipenessColor(ripeness),
                      ),
                      const SizedBox(height: 16),

                      // Disease Card
                      _buildResultCard(
                        context,
                        'Health Status',
                        disease.trim(),
                        _getDiseaseExplanation(disease),
                        Icons.healing,
                        _getDiseaseColor(disease),
                      ),
                      const SizedBox(height: 30),

                      // Action Button
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.camera_alt),
                        label: Text('Analyze Another Fruit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0d47a1),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    String title,
    String result,
    String explanation,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                explanation,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// History Page
class HistoryPage extends StatelessWidget {
  final List<AnalysisHistory> history;

  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1a237e),
              const Color(0xFF0d47a1),
              const Color(0xFF01579b),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Analysis History',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // History List
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 80,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No analysis history yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start analyzing fruits to see your history',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final item = history[index];
                          return _buildHistoryCard(context, item);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, AnalysisHistory item) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final imageFile = File(item.imagePath);
    final imageExists = imageFile.existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: imageExists
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ResultsPage(
                        image: imageFile,
                        fruitType: item.fruitType,
                        ripeness: item.ripeness,
                        disease: item.disease,
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Image Thumbnail
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[300],
                  ),
                  child: imageExists
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              );
                            },
                          ),
                        )
                      : Icon(Icons.image_not_supported, color: Colors.grey),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fruitType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildStatusChip(
                            item.ripeness,
                            _getRipenessColor(item.ripeness),
                          ),
                          _buildStatusChip(
                            item.disease,
                            _getDiseaseColor(item.disease),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateFormat.format(item.timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),

                // Arrow Icon
                Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Color _getRipenessColor(String ripeness) {
    final ripenessLower = ripeness.toLowerCase().trim();
    if (ripenessLower.contains('ripe') &&
        !ripenessLower.contains('unripe') &&
        !ripenessLower.contains('over')) {
      return Colors.green;
    } else if (ripenessLower.contains('unripe')) {
      return Colors.orange;
    } else if (ripenessLower.contains('over')) {
      return Colors.red;
    }
    return Colors.blue;
  }

  Color _getDiseaseColor(String disease) {
    final diseaseLower = disease.toLowerCase().trim();
    if (diseaseLower.contains('healthy') ||
        diseaseLower.contains('no disease') ||
        diseaseLower == '0') {
      return Colors.green;
    }
    return Colors.red;
  }
}
