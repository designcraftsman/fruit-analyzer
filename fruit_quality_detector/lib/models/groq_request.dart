/// Request model for Groq API
class GroqRequest {
  final List<GroqMessage> messages;
  final String model;
  final double temperature;
  final int maxTokens;
  final bool stream;

  GroqRequest({
    required this.messages,
    this.model = 'llama-3.3-70b-versatile',
    this.temperature = 0.7,
    this.maxTokens = 1024,
    this.stream = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((m) => m.toJson()).toList(),
      'model': model,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': stream,
    };
  }
}

/// Individual message in the conversation
class GroqMessage {
  final String role; // 'system', 'user', or 'assistant'
  final String content;

  GroqMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
  }
}
