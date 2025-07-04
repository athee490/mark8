import 'dart:typed_data';
import 'dart:math';
import 'dart:ui';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../utils/image_utils.dart';
import '../utils/tflite_helper.dart';
import 'human_follower.dart'; // for DetectedObject

class ObjectDetector {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  // Provide actual label list here
  final List<String> _labels = ['person', 'cat', 'dog'];

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

  List<DetectedObject> _extractBoundingBoxes(List<List<double>> output) {
    final boxes = <DetectedObject>[];
    for (var det in output) {
      if (det[4] > 0.5) {
        final classScores = det.sublist(5);
        final maxScore = classScores.reduce(max);
        final classId = classScores.indexOf(maxScore);
        final label = _labels[classId];

        final cx = det[0] * 640;
        final cy = det[1] * 640;
        final w = det[2] * 640;
        final h = det[3] * 640;
        final left = cx - w / 2;
        final top = cy - h / 2;

        boxes.add(DetectedObject(
          label: label,
          boundingBox: Rect.fromLTWH(left, top, w, h),
        ));
      }
    }
    return boxes;
  }

  void dispose() {
    _interpreter.close();
  }
}
