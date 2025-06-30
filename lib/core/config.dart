import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }

  static String get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? 'DEFAULT_KEY_IF_MISSING';
}