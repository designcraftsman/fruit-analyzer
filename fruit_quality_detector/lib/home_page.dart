import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruit_quality_detector/services/auth_service.dart';
import 'package:fruit_quality_detector/theme/app_theme.dart';
import 'package:fruit_quality_detector/widgets/loading_overlay.dart';
import 'package:fruit_quality_detector/utils/page_transitions.dart';
import 'package:fruit_quality_detector/screens/results_page.dart';
import 'package:fruit_quality_detector/screens/history_page.dart';

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
    String name = rawName.trim();
    name = name.replaceAll(
      RegExp(r'^(Rot_|Rotten_?|Fresh_?|Bad_?|Good_?)', caseSensitive: false),
      '',
    );
    name = name.replaceAll(RegExp(r'\d+'), '').trim();
    name = name.replaceAll('_', ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
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
    if (name.contains('ripe') &&
        !name.contains('unripe') &&
        !name.contains('over')) {
      return 'Ripe';
    } else if (name.contains('unripe')) {
      return 'Unripe';
    } else if (name.contains('over')) {
      return 'Overripe';
    }
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
    if (name == '0' ||
        name.toLowerCase().contains('healthy') ||
        name.toLowerCase().contains('no disease') ||
        name.toLowerCase() == 'fresh') {
      return 'Healthy';
    }
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
    name = name.replaceAll(RegExp(r'\d+'), '').trim();
    name = name.replaceAll('_', ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
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
    try {
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
    } catch (e) {
      // Silently handle model loading errors
    }
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
      setState(() => _loading = false);
      return;
    }

    try {
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
          ScaleFadePageRoute(
            page: ResultsPage(
              image: _image!,
              fruitType: _formatFruitName(_fruitResult),
              ripeness: _formatRipenessName(_ripenessResult),
              disease: _formatDiseaseName(_diseaseResult),
            ),
          ),
        );
      }
    } catch (e) {
      // Silently handle inference errors
      setState(() => _loading = false);
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

  String _getLoadingMessage() {
    switch (_currentStep) {
      case AnalysisStep.preprocessing:
        return 'Preprocessing image...';
      case AnalysisStep.detectingFruit:
        return 'Detecting fruit type...';
      case AnalysisStep.analyzingRipeness:
        return 'Analyzing ripeness...';
      case AnalysisStep.checkingDisease:
        return 'Checking for diseases...';
      case AnalysisStep.completed:
        return 'Analysis complete!';
      default:
        return 'Processing...';
    }
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Choose Image Source',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildImageSourceOption(
                    context,
                    icon: Icons.photo_library_rounded,
                    title: 'Gallery',
                    subtitle: 'Choose from photos',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildImageSourceOption(
                    context,
                    icon: Icons.camera_alt_rounded,
                    title: 'Camera',
                    subtitle: 'Take a new photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      maxWidth: AppResponsive.maxContentWidth(context),
                    ),
                    child: Padding(
                      padding: AppResponsive.responsivePadding(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.logout_rounded),
                                tooltip: 'Sign out',
                                onPressed: _signOut,
                                color: AppColors.textSecondary,
                              ),
                              IconButton(
                                icon: const Icon(Icons.history_rounded),
                                tooltip: 'History',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    ScaleFadePageRoute(
                                      page: HistoryPage(history: _history),
                                    ),
                                  );
                                },
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                          SizedBox(
                            height: AppResponsive.isMobile(context) ? 20 : 40,
                          ),

                          // Logo and Title
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.eco_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Fruit Quality',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'AI-Powered Analysis',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppColors.accent),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: AppResponsive.isMobile(context) ? 40 : 60,
                          ),

                          // Upload Card
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: AppResponsive.isMobile(context)
                                    ? double.infinity
                                    : 500,
                              ),
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.98, end: 1.0)
                                    .animate(
                                      CurvedAnimation(
                                        parent: _pulseController,
                                        curve: Curves.easeInOut,
                                      ),
                                    ),
                                child: Card(
                                  child: InkWell(
                                    onTap: () =>
                                        _showImageSourcePicker(context),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        AppResponsive.isMobile(context)
                                            ? 40.0
                                            : 60.0,
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppColors.primaryGradient,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.add_photo_alternate_rounded,
                                              size: 56,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            'Upload Image',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap to choose from gallery or camera',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Features
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildFeatureChip(
                                'Fruit Type',
                                Icons.apple_rounded,
                              ),
                              _buildFeatureChip('Ripeness', Icons.eco_rounded),
                              _buildFeatureChip(
                                'Health',
                                Icons.health_and_safety_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading overlay
          LoadingOverlay(message: _getLoadingMessage(), isVisible: _loading),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
