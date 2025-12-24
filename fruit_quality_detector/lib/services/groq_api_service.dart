import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fruit_quality_detector/models/groq_request.dart';
import 'package:fruit_quality_detector/models/groq_response.dart';
import 'package:fruit_quality_detector/models/fruit_analysis.dart';

/// Service for interacting with Groq API
class GroqApiService {
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _apiKeyStorageKey = 'groq_api_key';
  static const String _defaultModel = 'openai/gpt-oss-120b';

  // Available Groq models
  static const String modelLlama70b = 'llama-3.3-70b-versatile';
  static const String modelGptOss120b = 'openai/gpt-oss-120b';
  static const String modelMixtral = 'mixtral-8x7b-32768';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _cachedApiKey;
  String _currentModel = _defaultModel;

  /// Get the API key from secure storage or environment
  Future<String> _getApiKey() async {
    // Return cached key if available
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    // Try to get from secure storage first
    final storedKey = await _secureStorage.read(key: _apiKeyStorageKey);
    if (storedKey != null && storedKey.isNotEmpty) {
      _cachedApiKey = storedKey;
      return storedKey;
    }

    throw GroqApiException('Groq API key not found. Please set it up.');
  }

  /// Store API key securely
  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);
    _cachedApiKey = apiKey;
  }

  /// Check if API key is configured
  Future<bool> hasApiKey() async {
    try {
      final key = await _getApiKey();
      return key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Set the model to use for chat requests
  void setModel(String model) {
    _currentModel = model;
  }

  /// Get the current model being used
  String getCurrentModel() {
    return _currentModel;
  }

  /// Send a chat request to Groq API
  Future<GroqResponse> chat({
    required String userMessage,
    FruitAnalysis? fruitAnalysis,
    List<GroqMessage>? conversationHistory,
    String? model, // Optional: override the current model for this request
  }) async {
    try {
      final apiKey = await _getApiKey();

      // Build the messages array
      final messages = <GroqMessage>[];

      // Add system message with fruit context if available
      if (fruitAnalysis != null) {
        messages.add(
          GroqMessage(
            role: 'system',
            content: _buildSystemPrompt(fruitAnalysis),
          ),
        );
      } else {
        messages.add(
          GroqMessage(
            role: 'system',
            content:
                'You are a helpful nutritionist and fruit expert assistant. '
                'Provide accurate, concise, and helpful information about fruits, '
                'nutrition, and health. Keep responses conversational and friendly.',
          ),
        );
      }

      // Add conversation history if provided
      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }

      // Add current user message
      messages.add(GroqMessage(role: 'user', content: userMessage));

      // Create request
      final request = GroqRequest(
        messages: messages,
        model: model ?? _currentModel, // Use provided model or current model
        temperature: 0.7,
        maxTokens: 1024,
      );

      // Make HTTP request
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw GroqApiException('Request timeout. Please try again.');
            },
          );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return GroqResponse.fromJson(jsonResponse);
      } else if (response.statusCode == 401) {
        throw GroqApiException(
          'Invalid API key. Please check your configuration.',
        );
      } else if (response.statusCode == 429) {
        throw GroqApiException(
          'Rate limit exceeded. Please wait a moment and try again.',
        );
      } else {
        final errorBody = response.body;
        throw GroqApiException(
          'API request failed (${response.statusCode}): $errorBody',
        );
      }
    } on GroqApiException {
      rethrow;
    } catch (e) {
      throw GroqApiException('Failed to communicate with AI: $e');
    }
  }

  /// Build system prompt with fruit analysis context
  String _buildSystemPrompt(FruitAnalysis analysis) {
    return '''You are a helpful nutritionist and fruit expert assistant. The user has just analyzed a fruit using an AI-powered fruit quality detector app. Here are the analysis results:

${analysis.toContextString()}

${analysis.getNutritionalSummary()}

Your role is to:
1. Answer questions about this specific fruit's nutrition, health benefits, and quality
2. Provide dietary advice based on the fruit's condition and ripeness
3. Suggest recipes or consumption methods appropriate for the fruit's state
4. Address health concerns related to this fruit
5. Be encouraging and supportive about healthy eating

Keep your responses:
- Conversational and friendly
- Concise (2-4 sentences typically)
- Evidence-based but accessible
- Specific to the analyzed fruit when relevant

If asked about something unrelated to fruits or nutrition, politely redirect to topics you can help with.''';
  }

  /// Quick health check for the API
  Future<bool> testConnection() async {
    try {
      final response = await chat(userMessage: 'Hi', conversationHistory: []);
      return response.content.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear cached API key
  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyStorageKey);
    _cachedApiKey = null;
  }
}

/// Custom exception for Groq API errors
class GroqApiException implements Exception {
  final String message;
  GroqApiException(this.message);

  @override
  String toString() => message;
}
