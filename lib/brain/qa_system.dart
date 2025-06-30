import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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
    _geminiAvailable = const bool.fromEnvironment('GEMINI_API_KEY', defaultValue: false);
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
      final apiKey = const String.fromEnvironment('GEMINI_API_KEY');
      final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
      final content = Content.text(question);
      final response = await model.generateContent([content]);
      // google_generative_ai 0.2.0: text is in response.text
      return response.text ?? "I couldn't understand that question";
    } catch (e) {
      return "Connection error: ${e.toString()}";
    }
  }
}