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
    print('[QASystem] Loading QA database...');
    try {
      final data = await rootBundle.loadString('assets/qa_database.json');
      _qaDatabase = Map<String, String>.from(json.decode(data));
      print('[QASystem] QA database loaded: ${_qaDatabase.length} entries');
    } catch (e) {
      print('[QASystem] QA database error: $e');
    }

    _geminiAvailable = dotenv.env['GEMINI_API_KEY'] != null &&
        dotenv.env['GEMINI_API_KEY']!.isNotEmpty;
    print('[QASystem] Gemini available: $_geminiAvailable');
  }

  Future<String> answer(String question) async {
    print('[QASystem] Answering question: $question');

    final localAnswer = _findSimilarQuestion(question);
    if (localAnswer != null) {
      print('[QASystem] Found local answer: $localAnswer');
      return localAnswer;
    }

    if (_geminiAvailable) {
      print('[QASystem] Querying Gemini API...');
      final geminiAnswer = await _askGemini(question);
      print('[QASystem] Gemini answer: $geminiAnswer');
      return geminiAnswer;
    }

    print('[QASystem] No local or Gemini answer available');
    return "I don't know the answer to that.";
  }

  String? _findSimilarQuestion(String question) {
    print('[QASystem] Searching for similar question: $question');
    final qLower = question.toLowerCase();
    for (final entry in _qaDatabase.entries) {
      final keywords = entry.key.toLowerCase().split(' ');
      if (keywords.every(qLower.contains)) {
        print('[QASystem] Match found: ${entry.key}');
        return entry.value;
      }
    }
    print('[QASystem] No similar question found');
    return null;
  }

  Future<String> _askGemini(String question) async {
    print('[QASystem] Asking Gemini: $question');
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        print('[QASystem] Gemini API key missing');
        return "Gemini API key is missing.";
      }

      final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
      final response = await model.generateContent([Content.text(question)]);
      print('[QASystem] Gemini response: ${response.text}');
      return response.text ?? "I couldn't understand that question";
    } catch (e) {
      print('[QASystem] Gemini connection error: $e');
      return "Connection error: ${e.toString()}";
    }
  }
}
