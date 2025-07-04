import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TfLiteHelper {
  static Future<Interpreter> loadModel(String assetPath) async {
    final interpreter = await Interpreter.fromAsset(assetPath);
    return interpreter;
  }
}
