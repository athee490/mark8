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

  static String get geminiApiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      print('[Config] WARNING: GEMINI_API_KEY is missing, using fallback');
      return 'DEFAULT_KEY_IF_MISSING';
    }
    return key;
  }
}
