import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gemini_config.dart';

enum ChatRole { user, model }

class ChatMessage {
  ChatMessage(this.role, this.text, {this.isError = false});
  final ChatRole role;
  String text;
  bool isError;
}

/// Talks to the Gemini REST API directly (no extra package needed).
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  final http.Client _client = http.Client();

  /// Streams the reply piece by piece so text appears as it's written.
  Stream<String> streamReply({
    required List<ChatMessage> history,
    required String systemPrompt,
  }) async* {
    _ensureConfigured();

    final uri = Uri.parse(
      '${GeminiConfig.baseUrl}/models/${GeminiConfig.model}'
      ':streamGenerateContent?alt=sse',
    );

    final request = http.Request('POST', uri)
      ..headers.addAll(_headers)
      ..body = jsonEncode(_body(history, systemPrompt));

    final response =
        await _client.send(request).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw GeminiFailure(_errorMessage(response.statusCode, body));
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final blocked = json['promptFeedback']?['blockReason'];
      if (blocked != null) {
        throw GeminiFailure(
            "I can't help with that one. Try asking in a different way.");
      }

      final text = _extractText(json);
      if (text.isNotEmpty) yield text;
    }
  }

  /// One-shot answer (no streaming). Handy for buttons like
  /// "Summarize" or "Draft this section".
  Future<String> generate(String prompt, {String? systemPrompt}) async {
    _ensureConfigured();

    final uri = Uri.parse(
      '${GeminiConfig.baseUrl}/models/${GeminiConfig.model}:generateContent',
    );

    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode(_body(
            [ChatMessage(ChatRole.user, prompt)],
            systemPrompt,
          )),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw GeminiFailure(_errorMessage(response.statusCode, response.body));
    }
    return _extractText(jsonDecode(response.body) as Map<String, dynamic>)
        .trim();
  }

  // ------------------------------------------------------------ internals

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-goog-api-key': GeminiConfig.apiKey,
      };

  void _ensureConfigured() {
    if (!GeminiConfig.isConfigured) {
      throw GeminiFailure(
        'AI is not set up yet. Run the app with '
        '--dart-define-from-file=env.json (see AI_SETUP.md).',
      );
    }
  }

  Map<String, dynamic> _body(List<ChatMessage> history, String? systemPrompt) {
    var recent = history
        .where((m) => !m.isError && m.text.trim().isNotEmpty)
        .toList();
    if (recent.length > GeminiConfig.maxHistoryMessages) {
      recent = recent.sublist(recent.length - GeminiConfig.maxHistoryMessages);
    }
    // Gemini expects the conversation to start with the user.
    while (recent.isNotEmpty && recent.first.role != ChatRole.user) {
      recent.removeAt(0);
    }

    return {
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
      'contents': [
        for (final m in recent)
          {
            'role': m.role == ChatRole.user ? 'user' : 'model',
            'parts': [
              {'text': m.text}
            ],
          }
      ],
      'generationConfig': {
        'temperature': GeminiConfig.temperature,
        'maxOutputTokens': GeminiConfig.maxOutputTokens,
      },
    };
  }

  String _extractText(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    final parts = candidates.first['content']?['parts'] as List?;
    if (parts == null) return '';
    return parts
        .where((p) => p is Map && p['thought'] != true)
        .map((p) => (p as Map)['text'] as String? ?? '')
        .join();
  }

  String _errorMessage(int status, String body) {
    String detail = '';
    try {
      detail = (jsonDecode(body)['error']?['message'] as String?) ?? '';
    } catch (_) {}

    switch (status) {
      case 400:
        if (detail.contains('API key')) {
          return 'The Gemini API key is invalid. Check env.json.';
        }
        return 'The AI could not read that request. ($detail)';
      case 401:
      case 403:
        return 'The Gemini API key was rejected. Make a new key at '
            'aistudio.google.com and put it in env.json.';
      case 404:
        return 'Model "${GeminiConfig.model}" was not found. '
            'Check the model name in gemini_config.dart.';
      case 429:
        return "You've hit the free AI limit for now. "
            'Wait a minute and try again.';
      case 500:
      case 503:
        return 'The AI is busy right now. Please try again in a moment.';
      default:
        return 'AI error ($status). $detail';
    }
  }
}

class GeminiFailure implements Exception {
  GeminiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}