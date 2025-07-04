import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static Future<void> load() async {
    try {
      print('[Config] Loading .env file...');
      await dotenv.load(fileName: ".env");
      print('[Config] .env loaded');
    } catch (e, st) {
      print('[Config] Error loading .env: $e\n$st');
      rethrow;
    }
  }

  static String get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? 'DEFAULT_KEY_IF_MISSING';
}