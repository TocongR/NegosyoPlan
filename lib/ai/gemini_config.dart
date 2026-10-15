/// Gemini settings.
///
/// The API key is NOT written in the code. Pass it when you run/build:
///   flutter run --dart-define-from-file=env.json
/// where env.json contains: {"GEMINI_API_KEY": "your-key"}
class GeminiConfig {
  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.1-flash-lite',
  );

  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// Only the last N messages are sent each time (saves your free quota).
  static const int maxHistoryMessages = 12;

  /// Caps reply length (saves quota, keeps answers phone-sized).
  static const int maxOutputTokens = 1024;

  static const double temperature = 0.6;

  static bool get isConfigured => apiKey.isNotEmpty;
}