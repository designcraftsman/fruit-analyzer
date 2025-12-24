import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

/// Enhanced voice service with automatic voice activity detection
/// Features:
/// - Automatic voice detection (no button press needed)
/// - Silence detection and auto-stop
/// - Continuous listening mode
/// - Voice activity callbacks
class VoiceServiceAuto {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isVoiceDetected = false;

  // Silence detection configuration
  Timer? _silenceTimer;
  DateTime? _lastSpeechTime;
  Duration _silenceThreshold = const Duration(seconds: 2);
  Duration _initialSilenceThreshold = const Duration(seconds: 5);
  double _soundLevelThreshold = 0.5;

  // Callbacks
  Function(String)? _onFinalResult;
  Function(String)? _onPartialResult;
  Function(bool)? _onVoiceActivityChanged;
  Function(String)? _onError;
  Function()? _onSilenceDetected;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isVoiceDetected => _isVoiceDetected;

  /// Initialize the voice services
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        throw VoicePermissionException('Microphone permission denied');
      }

      // Initialize speech-to-text
      bool available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );

      if (!available) {
        throw VoiceInitializationException('Speech recognition not available');
      }

      // Initialize text-to-speech
      await _configureTts();

      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// Configure text-to-speech settings
  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Listen to TTS completion
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  /// Start continuous listening with automatic voice detection
  /// This will listen passively and detect when the user starts speaking
  Future<void> startContinuousListening({
    required Function(String) onFinalResult,
    Function(String)? onPartialResult,
    Function(bool)? onVoiceActivityChanged,
    Function()? onSilenceDetected,
    Function(String)? onError,
    double soundLevelThreshold = 0.5,
    Duration silenceThreshold = const Duration(seconds: 2),
    Duration initialSilenceThreshold = const Duration(seconds: 5),
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Stop any existing listening session
    if (_isListening) {
      await stopListening();
    }

    // Store callbacks
    _onFinalResult = onFinalResult;
    _onPartialResult = onPartialResult;
    _onVoiceActivityChanged = onVoiceActivityChanged;
    _onSilenceDetected = onSilenceDetected;
    _onError = onError;

    _soundLevelThreshold = soundLevelThreshold;
    _silenceThreshold = silenceThreshold;
    _initialSilenceThreshold = initialSilenceThreshold;

    _lastSpeechTime = null;
    _isVoiceDetected = false;

    await _startListeningSession();
  }

  /// Internal method to start a listening session
  Future<void> _startListeningSession() async {
    try {
      await _speech.listen(
        onResult: _handleSpeechResult,
        listenFor: const Duration(seconds: 60), // Long session
        pauseFor: const Duration(seconds: 3), // Pause before finalizing
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
        onSoundLevelChange: _handleSoundLevel,
      );
      _isListening = true;

      // Start initial silence detection
      _startSilenceDetection(useInitialThreshold: true);
    } catch (e) {
      _isListening = false;
      _onError?.call(e.toString());
      rethrow;
    }
  }

  /// Handle speech recognition results
  void _handleSpeechResult(dynamic result) {
    final text = result.recognizedWords;

    if (text.isNotEmpty) {
      // Update last speech time
      _lastSpeechTime = DateTime.now();

      // Detect voice activity
      if (!_isVoiceDetected) {
        _isVoiceDetected = true;
        _onVoiceActivityChanged?.call(true);
      }

      // Reset silence timer
      _resetSilenceTimer();

      if (result.finalResult) {
        // Final result - send the message
        _isVoiceDetected = false;
        _onVoiceActivityChanged?.call(false);
        _onFinalResult?.call(text);

        // Restart listening for next input
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isListening) {
            _lastSpeechTime = null;
            _startListeningSession();
          }
        });
      } else {
        // Partial result - update UI
        _onPartialResult?.call(text);
      }
    }
  }

  /// Handle sound level changes for voice activity detection
  void _handleSoundLevel(double level) {
    // Sound level is typically between -2 (quiet) and 10 (loud)
    // We consider anything above 0 as potential speech
    if (level > _soundLevelThreshold) {
      _lastSpeechTime = DateTime.now();

      if (!_isVoiceDetected) {
        _isVoiceDetected = true;
        _onVoiceActivityChanged?.call(true);
      }

      _resetSilenceTimer();
    }
  }

  /// Start silence detection timer
  void _startSilenceDetection({bool useInitialThreshold = false}) {
    _silenceTimer?.cancel();

    final threshold = useInitialThreshold
        ? _initialSilenceThreshold
        : _silenceThreshold;

    _silenceTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_lastSpeechTime != null) {
        final silenceDuration = DateTime.now().difference(_lastSpeechTime!);

        if (silenceDuration > threshold && _isVoiceDetected) {
          // Silence detected after speech - trigger auto-stop
          _handleSilenceTimeout();
          timer.cancel();
        }
      }
    });
  }

  /// Reset the silence detection timer
  void _resetSilenceTimer() {
    _startSilenceDetection(useInitialThreshold: false);
  }

  /// Handle silence timeout (auto-stop)
  void _handleSilenceTimeout() {
    _silenceTimer?.cancel();

    if (_isVoiceDetected) {
      _isVoiceDetected = false;
      _onVoiceActivityChanged?.call(false);
      _onSilenceDetected?.call();

      // Stop current listening and wait for speech to finalize
      _speech.stop();
    }
  }

  /// Handle speech status changes
  void _handleSpeechStatus(String status) {
    if (status == 'listening') {
      _isListening = true;
    } else if (status == 'notListening' || status == 'done') {
      _isListening = false;

      // If we were in continuous mode, restart
      if (_onFinalResult != null && _isInitialized) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!_isListening && _onFinalResult != null) {
            _lastSpeechTime = null;
            _isVoiceDetected = false;
            _startListeningSession();
          }
        });
      }
    }
  }

  /// Handle speech errors
  void _handleSpeechError(dynamic error) {
    _isListening = false;
    _isVoiceDetected = false;
    _onVoiceActivityChanged?.call(false);
    _onError?.call(error.errorMsg);

    // Try to restart listening after error
    Future.delayed(const Duration(seconds: 1), () {
      if (_onFinalResult != null && _isInitialized) {
        _lastSpeechTime = null;
        _startListeningSession();
      }
    });
  }

  /// Stop listening (manually)
  Future<void> stopListening() async {
    _silenceTimer?.cancel();
    _onFinalResult = null;
    _onPartialResult = null;
    _onVoiceActivityChanged = null;
    _onSilenceDetected = null;
    _onError = null;

    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      _isVoiceDetected = false;
    }
  }

  /// Speak the given text aloud
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _isSpeaking = true;
      await _tts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      throw VoiceException('Failed to speak text: $e');
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Check if TTS is currently speaking
  Future<bool> isTtsSpeaking() async {
    // Note: flutter_tts doesn't have a direct isSpeaking check
    // We track it internally
    return _isSpeaking;
  }

  /// Dispose of resources
  void dispose() {
    _silenceTimer?.cancel();
    _speech.stop();
    _tts.stop();
    _onFinalResult = null;
    _onPartialResult = null;
    _onVoiceActivityChanged = null;
    _onSilenceDetected = null;
    _onError = null;
  }
}

/// Custom exceptions for voice service
class VoiceException implements Exception {
  final String message;
  VoiceException(this.message);

  @override
  String toString() => message;
}

class VoicePermissionException extends VoiceException {
  VoicePermissionException(super.message);
}

class VoiceInitializationException extends VoiceException {
  VoiceInitializationException(super.message);
}
