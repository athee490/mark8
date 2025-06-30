import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QASystem {
  static const double similarityThreshold = 0.8;
  Map<String, String> _qaDatabase = {};
  bool _geminiAvailable = false;

  Future<void> loadDatabase() async {
    try {
      final data = await rootBundle.loadString('assets/qa_database.json');
      _qaDatabase = Map<String, String>.from(json.decode(data));
    } catch (e) {
      debugPrint("QA database error: $e");
    }
    // Check Gemini availability
    _geminiAvailable = dotenv.env['GEMINI_API_KEY'] != null && dotenv.env['GEMINI_API_KEY']!.isNotEmpty;
  }

  Future<String> answer(String question) async {
    // 1. Try local database
    final localAnswer = _findSimilarQuestion(question);
    if (localAnswer != null) return localAnswer;
    // 2. Try Gemini API
    if (_geminiAvailable) {
      return await _askGemini(question);
    }
    return "I don't know the answer to that";
  }

  String? _findSimilarQuestion(String question) {
    final qLower = question.toLowerCase();
    // Simple keyword matching
    for (final entry in _qaDatabase.entries) {
      final keywords = entry.key.toLowerCase().split(' ');
      if (keywords.every(qLower.contains)) {
        return entry.value;
      }
    }
    return null;
  }

  Future<String> _askGemini(String question) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        return "Gemini API key is missing.";
      }
      final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
      final response = await model.generateContent([Content.text(question)]);
      return response.text ?? "I couldn't understand that question";
    } catch (e) {
      return "Connection error: ${e.toString()}";
    }
  }
}