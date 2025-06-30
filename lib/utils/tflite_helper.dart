import 'package:tflite_flutter/tflite_flutter.dart';

class TfLiteHelper {
  static Future<Interpreter> loadModel(String assetPath) async {
    try {
      return Interpreter.fromAsset(
        assetPath,
        options: InterpreterOptions()..threads = 4,
      );
    } catch (e) {
      throw Exception("Failed to load model $assetPath: $e");
    }
  }
}