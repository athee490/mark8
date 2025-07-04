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

class ObjectDetector {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  final List<String> _labels = ['person', 'car', 'dog']; // Add your real labels
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

  Future<List<DetectedObject>> detectObjectsWithBoxes(Uint8List imageBytes) async {
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

    return _extractBoundingBoxes(outputBuffer[0]);
  }

  List<DetectedObject> _extractBoundingBoxes(List<List<double>> output) {
    final boxes = <DetectedObject>[];

    for (final prediction in output) {
      if (prediction[4] > 0.5) {
        final classScores = prediction.sublist(5);
        final maxScore = classScores.reduce(max);
        final classIndex = classScores.indexOf(maxScore);

        final centerX = prediction[0];
        final centerY = prediction[1];
        final width = prediction[2];
        final height = prediction[3];

        final left = centerX - width / 2;
        final top = centerY - height / 2;
        final right = centerX + width / 2;
        final bottom = centerY + height / 2;

        boxes.add(
          DetectedObject(
            label: _labels[classIndex],
            boundingBox: Rect.fromLTRB(left.toDouble(), top.toDouble(), right.toDouble(), bottom.toDouble()),
          ),
        );
      }
    }

    return boxes;
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
