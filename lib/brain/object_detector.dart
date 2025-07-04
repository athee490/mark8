import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../utils/tflite_helper.dart';
import '../utils/image_utils.dart';
import 'dart:math';

List<List<List<double>>> reshape1DTo3D(List<double> input, int d1, int d2, int d3) {
  return List.generate(d1, (i) =>
    List.generate(d2, (j) =>
      input.sublist((i * d2 + j) * d3, (i * d2 + j + 1) * d3)
    )
  );
}

class ObjectDetector {
  late Interpreter _interpreter;
  final List<String> _labels = [ /* full label list omitted for brevity */ ];
  bool _isInitialized = false;
  List<String> lastDetectedObjects = [];

  Future<void> loadModel() async {
    print('[ObjectDetector] Loading model...');
    try {
      _interpreter = await TfLiteHelper.loadModel('assets/models/yolov5n.tflite');
      _isInitialized = true;
      print('[ObjectDetector] Model loaded successfully');
    } catch (e) {
      print('[ObjectDetector] Failed to load object detector: $e');
      throw Exception("Failed to load object detector: $e");
    }
  }

  Future<List<String>> detectObjects(Uint8List imageBytes) async {
    print('[ObjectDetector] detectObjects called');
    if (!_isInitialized) {
      print('[ObjectDetector] Not initialized');
      return [];
    }

    final inputImage = img.decodeImage(imageBytes);
    if (inputImage == null) {
      print('[ObjectDetector] Failed to decode image');
      return [];
    }

    print('[ObjectDetector] Image decoded: ${inputImage.width}x${inputImage.height}');
    final resized = img.copyResize(inputImage, width: 640, height: 640);
    print('[ObjectDetector] Image resized to 640x640');
    final input = ImageUtils.imageToFloat32List(resized, 640, 640);
    print('[ObjectDetector] Image converted to float32');

    final output = List.filled(25200 * 85, 0.0);
    _interpreter.run(input, output);
    print('[ObjectDetector] Inference complete');

    final output3d = reshape1DTo3D(output, 1, 25200, 85);
    print('[ObjectDetector] Output reshaped');

    lastDetectedObjects = _processOutput(output3d[0]);
    print('[ObjectDetector] Detected: $lastDetectedObjects');

    return lastDetectedObjects;
  }

  List<String> _processOutput(List<List<double>> output) {
    print('[ObjectDetector] Processing output...');
    final results = <String>[];
    for (var detection in output) {
      final confidence = detection[4];
      if (confidence > 0.5) {
        final classScores = detection.sublist(5);
        final maxScore = classScores.reduce(max);
        final classId = classScores.indexOf(maxScore);
        results.add(_labels[classId]);
      }
    }
    final unique = results.toSet().toList();
    print('[ObjectDetector] Unique objects: $unique');
    return unique;
  }

  void dispose() {
    print('[ObjectDetector] Disposing interpreter');
    _interpreter.close();
  }
}
