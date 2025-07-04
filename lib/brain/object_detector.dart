import 'dart:typed_data';
import 'dart:math';
import 'dart:ui';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../utils/tflite_helper.dart';
import '../utils/image_utils.dart';

class DetectedObject {
  final String label;
  final Rect boundingBox;
  DetectedObject({required this.label, required this.boundingBox});
}

List<List<List<double>>> reshape1DTo3D(List<double> input, int d1, int d2, int d3) {
  return List.generate(d1, (i) =>
    List.generate(d2, (j) =>
      input.sublist((i * d2 + j) * d3, (i * d2 + j + 1) * d3)
    )
  );
}

class ObjectDetector {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  final List<String> _labels = [...]; // your label list here
  List<String> _lastDetectedObjects = [];
  List<String> get lastDetectedObjects => _lastDetectedObjects;

  Future<void> loadModel() async {
    print('[ObjectDetector] Loading YOLOv5 model...');
    try {
      _interpreter = await TfLiteHelper.loadModel('assets/models/yolov5n.tflite');
      _interpreter.allocateTensors();
      _isInitialized = true;
      print('[ObjectDetector] Model loaded and tensors allocated');
    } catch (e) {
      print('[ObjectDetector] Failed to load model: $e');
      throw Exception("Failed to load object detector: $e");
    }
  }

  Future<List<String>> detectObjects(Uint8List imageBytes) async {
    if (!_isInitialized) return [];

    final inputImage = img.decodeImage(imageBytes);
    if (inputImage == null) return [];

    final resized = img.copyResize(inputImage, width: 640, height: 640);
    final input = ImageUtils.imageToFloat32List(resized, 640, 640);
    final inputBuffer = input.reshape([1, 640, 640, 3]);

    final outputBuffer = List.filled(25200 * 85, 0.0).reshape([1, 25200, 85]);

    try {
      _interpreter.run(inputBuffer, outputBuffer);
    } catch (e) {
      print('[ObjectDetector] Inference error: $e');
      return [];
    }

    final output3d = outputBuffer;
    _lastDetectedObjects = _processOutput(output3d[0]);
    return _lastDetectedObjects;
  }

  List<String> _processOutput(List<List<double>> output) {
    final results = <String>[];
    for (var det in output) {
      if (det[4] > 0.5) {
        final classScores = det.sublist(5);
        final maxScore = classScores.reduce(max);
        final classId = classScores.indexOf(maxScore);
        results.add(_labels[classId]);
      }
    }
    return results.toSet().toList();
  }

  void dispose() {
    _interpreter.close();
  }
}
