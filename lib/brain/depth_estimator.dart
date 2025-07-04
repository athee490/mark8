import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../utils/tflite_helper.dart';
import '../utils/image_utils.dart';

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
      _isInitialized = true;
      print('[DepthEstimator] Model loaded successfully');
    } catch (e) {
      print('[DepthEstimator] Error loading model: $e');
      throw Exception("Failed to load depth model: $e");
    }
  }

  Future<List<List<double>>> estimateDepth(Uint8List imageBytes) async {
    print('[DepthEstimator] estimateDepth called');
    if (!_isInitialized) {
      print('[DepthEstimator] Not initialized');
      return [];
    }

    try {
      // Decode and resize image
      final inputImage = img.decodeImage(imageBytes);
      if (inputImage == null) {
        print('[DepthEstimator] Failed to decode image');
        return [];
      }

      print('[DepthEstimator] Original image size: ${inputImage.width}x${inputImage.height}');
      final resized = img.copyResize(inputImage, width: 256, height: 256);
      print('[DepthEstimator] Image resized to 256x256');

      // Convert to float32 input tensor
      final input = ImageUtils.imageToFloat32List(resized, 256, 256);
      print('[DepthEstimator] Image converted to Float32 input');

      // Run inference
      final output = List.filled(256 * 256, 0.0);
      _interpreter.run(input, output);
      print('[DepthEstimator] Inference completed');

      final depthMap = reshape1DTo2D(output, 256, 256);
      print('[DepthEstimator] Depth map generated');
      return depthMap;
    } catch (e) {
      print('[DepthEstimator] Error estimating depth: $e');
      return [];
    }
  }

  void dispose() {
    print('[DepthEstimator] Disposing interpreter');
    _interpreter.close();
  }
}
