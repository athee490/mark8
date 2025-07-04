import 'package:tflite_flutter/tflite_flutter.dart';

class TfLiteHelper {
  static Future<Interpreter> loadModel(String assetPath) async {
    print('[TfLiteHelper] loadModel called: assetPath=$assetPath');
    try {
      final interpreter = Interpreter.fromAsset(
        assetPath,
        options: InterpreterOptions()..threads = 4,
      );
      print('[TfLiteHelper] Model loaded successfully: $assetPath');
      return interpreter;
    } catch (e) {
      print('[TfLiteHelper] Failed to load model $assetPath: $e');
      throw Exception("Failed to load model $assetPath: $e");
    }
  }
}