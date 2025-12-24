/// Response model from Groq API
class GroqResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<GroqChoice> choices;
  final GroqUsage usage;

  GroqResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
  });

  factory GroqResponse.fromJson(Map<String, dynamic> json) {
    return GroqResponse(
      id: json['id'] ?? '',
      object: json['object'] ?? '',
      created: json['created'] ?? 0,
      model: json['model'] ?? '',
      choices:
          (json['choices'] as List?)
              ?.map((c) => GroqChoice.fromJson(c))
              .toList() ??
          [],
      usage: GroqUsage.fromJson(json['usage'] ?? {}),
    );
  }

  String get content {
    if (choices.isEmpty) return '';
    return choices[0].message.content;
  }
}

/// Individual choice from the response
class GroqChoice {
  final int index;
  final GroqResponseMessage message;
  final String finishReason;

  GroqChoice({
    required this.index,
    required this.message,
    required this.finishReason,
  });

  factory GroqChoice.fromJson(Map<String, dynamic> json) {
    return GroqChoice(
      index: json['index'] ?? 0,
      message: GroqResponseMessage.fromJson(json['message'] ?? {}),
      finishReason: json['finish_reason'] ?? '',
    );
  }
}

/// Message in the response
class GroqResponseMessage {
  final String role;
  final String content;

  GroqResponseMessage({required this.role, required this.content});

  factory GroqResponseMessage.fromJson(Map<String, dynamic> json) {
    return GroqResponseMessage(
      role: json['role'] ?? '',
      content: json['content'] ?? '',
    );
  }
}

/// Usage statistics
class GroqUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  GroqUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory GroqUsage.fromJson(Map<String, dynamic> json) {
    return GroqUsage(
      promptTokens: json['prompt_tokens'] ?? 0,
      completionTokens: json['completion_tokens'] ?? 0,
      totalTokens: json['total_tokens'] ?? 0,
    );
  }
}
