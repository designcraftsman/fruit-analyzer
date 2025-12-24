import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fruit_quality_detector/models/chat_message.dart';
import 'package:fruit_quality_detector/models/fruit_analysis.dart';
import 'package:fruit_quality_detector/models/groq_request.dart';
import 'package:fruit_quality_detector/services/voice_service_auto.dart';
import 'package:fruit_quality_detector/services/groq_api_service.dart';

/// Modern GPT-like voice chat widget with automatic voice detection
/// Features:
/// - No tap-to-speak button
/// - Automatic voice detection and recording
/// - Auto-stop on silence
/// - Animated listening indicator (glow ring)
/// - Modern chat bubbles (GPT-style)
/// - Bottom floating card UI
/// - Optional voice playback of AI responses
class VoiceChatModernWidget extends StatefulWidget {
  final FruitAnalysis? fruitAnalysis;
  final bool autoSpeakResponses;
  final Color? accentColor;

  const VoiceChatModernWidget({
    super.key,
    this.fruitAnalysis,
    this.autoSpeakResponses = false,
    this.accentColor,
  });

  @override
  State<VoiceChatModernWidget> createState() => _VoiceChatModernWidgetState();
}

class _VoiceChatModernWidgetState extends State<VoiceChatModernWidget>
    with TickerProviderStateMixin {
  final VoiceServiceAuto _voiceService = VoiceServiceAuto();
  final GroqApiService _groqService = GroqApiService();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isVoiceActive = false;
  bool _isProcessingAI = false;
  String _partialText = '';
  String? _errorMessage;

  // Animation controllers
  late AnimationController _glowController;
  late AnimationController _waveController;
  late Animation<double> _glowAnimation;

  Color get accentColor => widget.accentColor ?? Colors.deepPurple;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeServices();
  }

  void _setupAnimations() {
    // Glow animation for listening indicator
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Wave animation for voice activity
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _waveController.dispose();
    _scrollController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // Check if API key is configured
      final hasKey = await _groqService.hasApiKey();
      if (!hasKey) {
        setState(() {
          _errorMessage =
              'Please configure your Groq API key in secure storage.';
        });
        return;
      }

      _groqService.setModel(GroqApiService.modelGptOss120b);

      // Initialize voice service
      await _voiceService.initialize();

      setState(() => _isInitialized = true);

      // Add welcome message
      _addMessage(
        ChatMessage(
          id: DateTime.now().toString(),
          content: widget.fruitAnalysis != null
              ? "Hi! I'm listening. Ask me anything about this ${widget.fruitAnalysis!.fruitType}. Just start speaking - no button needed!"
              : "Hi! I'm your AI assistant. Just start speaking - I'm listening passively and will respond automatically.",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );

      // Start continuous listening automatically
      _startContinuousListening();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: ${e.toString()}';
      });
    }
  }

  Future<void> _startContinuousListening() async {
    try {
      await _voiceService.startContinuousListening(
        onFinalResult: _handleFinalSpeech,
        onPartialResult: _handlePartialSpeech,
        onVoiceActivityChanged: _handleVoiceActivityChanged,
        onSilenceDetected: _handleSilenceDetected,
        onError: _handleVoiceError,
      );

      setState(() => _isListening = true);
      _glowController.repeat(reverse: true);
    } catch (e) {
      _showError('Failed to start listening: ${e.toString()}');
    }
  }

  void _handlePartialSpeech(String text) {
    setState(() => _partialText = text);
  }

  void _handleFinalSpeech(String text) async {
    if (text.trim().isEmpty) return;

    setState(() => _partialText = '');

    // Add user message
    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _addMessage(userMessage);

    // Get AI response
    await _getAIResponse(text);
  }

  void _handleVoiceActivityChanged(bool isActive) {
    setState(() => _isVoiceActive = isActive);
  }

  void _handleSilenceDetected() {
    // Silence detected - message will be sent via onFinalResult
    setState(() {
      _isVoiceActive = false;
      _partialText = '';
    });
  }

  void _handleVoiceError(String error) {
    if (error.contains('permission')) {
      _showError(
        'Microphone permission denied. Please enable it in your device settings.',
      );
    } else {
      // Don't show minor errors, just log them
      debugPrint('Voice error: $error');
    }
  }

  Future<void> _getAIResponse(String userMessage) async {
    setState(() => _isProcessingAI = true);

    try {
      // Build conversation history
      final conversationHistory = _messages
          .where((m) => !m.isError)
          .skip(1) // Skip welcome message
          .map(
            (m) => GroqMessage(
              role: m.isUser ? 'user' : 'assistant',
              content: m.content,
            ),
          )
          .toList();

      // Get AI response from Groq
      final response = await _groqService.chat(
        userMessage: userMessage,
        fruitAnalysis: widget.fruitAnalysis,
        conversationHistory: conversationHistory,
      );

      // Add AI response
      final aiMessage = ChatMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        content: response.content,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(aiMessage);

      // Speak response if enabled
      if (widget.autoSpeakResponses && response.content.isNotEmpty) {
        await _voiceService.speak(response.content);
      }
    } catch (e) {
      final errorMessage = ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        content: _getErrorMessage(e),
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );
      _addMessage(errorMessage);
    } finally {
      setState(() => _isProcessingAI = false);
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please check your connection.';
    } else if (errorStr.contains('API key')) {
      return 'API configuration issue. Please check your Groq API key.';
    } else if (errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    } else {
      return 'Sorry, I encountered an error. Please try again.';
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() => _messages.add(message));

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor.withOpacity(0.05), Colors.white],
        ),
      ),
      child: Column(
        children: [
          // App bar
          _buildAppBar(),

          // Chat messages
          Expanded(child: _buildChatArea()),

          // Bottom floating card with listening indicator
          _buildBottomCard(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Assistant',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  Text(
                    _isListening
                        ? _isVoiceActive
                              ? 'Listening...'
                              : 'Ready - Start speaking'
                        : 'Initializing...',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isVoiceActive
                          ? accentColor
                          : Colors.grey.shade600,
                      fontWeight: _isVoiceActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Status indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _isListening ? Colors.green : Colors.grey.shade400,
                shape: BoxShape.circle,
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    if (_errorMessage != null && !_isInitialized) {
      return _buildErrorState();
    }

    if (_messages.isEmpty) {
      return _buildLoadingState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length + (_isProcessingAI ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator();
        }

        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final isError = message.isError;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(isUser: false, isError: isError),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isError
                        ? Colors.red.shade50
                        : isUser
                        ? accentColor
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isError
                          ? Colors.red.shade900
                          : isUser
                          ? Colors.white
                          : Colors.grey.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            _buildAvatar(isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar({required bool isUser, bool isError = false}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: isError
            ? LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600])
            : isUser
            ? LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              )
            : LinearGradient(
                colors: [accentColor.withOpacity(0.8), accentColor],
              ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color:
                (isError
                        ? Colors.red
                        : isUser
                        ? Colors.blue
                        : accentColor)
                    .withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        isError
            ? Icons.error_outline
            : isUser
            ? Icons.person
            : Icons.smart_toy,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(isUser: false),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final offset = math.sin(
          (_waveController.value * 2 * math.pi) + (index * math.pi / 3),
        );
        return Transform.translate(
          offset: Offset(0, offset * 3),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Listening indicator
            if (_isListening) _buildListeningIndicator(),

            // Partial text display
            if (_partialText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _partialText,
                  style: TextStyle(
                    fontSize: 14,
                    color: accentColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            // Status text
            if (_partialText.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _isVoiceActive
                    ? 'Listening to you...'
                    : _isProcessingAI
                    ? 'Thinking...'
                    : 'Ready to listen - Just start speaking',
                style: TextStyle(
                  fontSize: 14,
                  color: _isVoiceActive ? accentColor : Colors.grey.shade600,
                  fontWeight: _isVoiceActive
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListeningIndicator() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accentColor.withOpacity(
                  _isVoiceActive ? _glowAnimation.value : 0.3,
                ),
                accentColor.withOpacity(0.0),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _isVoiceActive ? accentColor : Colors.grey.shade400,
                shape: BoxShape.circle,
                boxShadow: _isVoiceActive
                    ? [
                        BoxShadow(
                          color: accentColor.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _isVoiceActive ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: accentColor),
          const SizedBox(height: 16),
          Text(
            'Initializing voice assistant...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeServices,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
