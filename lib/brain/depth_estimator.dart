import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../utils/image_utils.dart';
import '../utils/tflite_helper.dart';

List<List<double>> reshape1DTo2D(List<double> input, int rows, int cols) {
  return List.generate(rows, (i) => input.sublist(i * cols, (i + 1) * cols));
}

class DepthEstimator {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  Future<void> loadModel() async {
    print('[DepthEstimator] Loading MiDaS depth model...');
    try {
      _interpreter = await TfLiteHelper.loadModel('assets/models/midas_small.tflite');
      _interpreter.allocateTensors();
      _isInitialized = true;
      print('[DepthEstimator] Model loaded and tensors allocated');
    } catch (e) {
      print('[DepthEstimator] Error loading model: $e');
    }
  }

  Future<List<List<double>>> estimateDepth(Uint8List imageBytes) async {
    if (!_isInitialized) return [];

    final inputImage = img.decodeImage(imageBytes);
    if (inputImage == null) return [];

    final resized = img.copyResize(inputImage, width: 256, height: 256);
    final input = ImageUtils.imageToFloat32List(resized, 256, 256);
    final output = List<double>.filled(256 * 256, 0.0);

    try {
      _interpreter.run(input, output);
    } catch (e) {
      print('[DepthEstimator] Inference error: $e');
      return [];
    }

    return reshape1DTo2D(output, 256, 256);
  }

  void dispose() {
    _interpreter.close();
  }
}
