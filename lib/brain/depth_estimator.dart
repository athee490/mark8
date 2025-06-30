import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../utils/tflite_helper.dart';
import '../utils/image_utils.dart';

class DepthEstimator {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  Future<void> loadModel() async {
    try {
      _interpreter = await TfLiteHelper.loadModel('assets/models/midas_small.tflite');
      _isInitialized = true;
    } catch (e) {
      throw Exception("Failed to load depth model: $e");
    }
  }

  Future<List<List<double>>> estimateDepth(Uint8List imageBytes) async {
    if (!_isInitialized) return [];

    // Preprocess image
    final inputImage = img.decodeImage(imageBytes)!;
    final resized = img.copyResize(inputImage, width: 256, height: 256);
    final input = ImageUtils.imageToFloat32List(resized, 256, 256);
    
    // Run inference
    final output = List.filled(256 * 256, 0.0).reshape([1, 256, 256]);
    _interpreter.run(input, output);
    
    return output[0];
  }

  void dispose() {
    _interpreter.close();
  }
}