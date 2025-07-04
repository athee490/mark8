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
      _interpreter.allocateTensors();
      _isInitialized = true;
      print('[DepthEstimator] Model loaded and tensors allocated');
    } catch (e) {
      print('[DepthEstimator] Error loading model: $e');
      throw Exception("Failed to load depth model: $e");
    }
  }

  Future<List<List<double>>> estimateDepth(Uint8List imageBytes) async {
    print('[DepthEstimator] estimateDepth called');
    if (!_isInitialized) return [];

    final inputImage = img.decodeImage(imageBytes);
    if (inputImage == null) {
      print('[DepthEstimator] Failed to decode image');
      return [];
    }

    final resized = img.copyResize(inputImage, width: 256, height: 256);
    final input = ImageUtils.imageToFloat32List(resized, 256, 256);

    var inputTensor = _interpreter.getInputTensor(0);
    var shape = inputTensor.shape;
    var type = inputTensor.type;

    print('[DepthEstimator] Input tensor shape: $shape, type: $type');

    final inputBuffer = input.reshape([1, 256, 256, 3]);

    final outputBuffer = List.filled(256 * 256, 0.0).reshape([1, 256, 256]);

    try {
      _interpreter.run(inputBuffer, outputBuffer);
    } catch (e) {
      print('[DepthEstimator] Inference error: $e');
      return [];
    }

    final flat = outputBuffer.expand((e) => e).toList();
    return reshape1DTo2D(flat, 256, 256);
  }

  void dispose() {
    _interpreter.close();
  }
}
