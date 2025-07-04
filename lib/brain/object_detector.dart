// object_detector.dart
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
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
  final List<String> _labels = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
    'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat',
    'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack',
    'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball',
    'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
    'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
    'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair',
    'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote',
    'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink', 'refrigerator', 'book',
    'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
  ];

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
    if (!_isInitialized) return [];

    final inputImage = img.decodeImage(imageBytes);
    if (inputImage == null) return [];

    final resized = img.copyResize(inputImage, width: 640, height: 640);
    final input = ImageUtils.imageToFloat32List(resized, 640, 640);
    final output = List.filled(25200 * 85, 0.0);

    _interpreter.run(input, output);

    final output3d = reshape1DTo3D(output, 1, 25200, 85);
    lastDetectedObjects = _processOutput(output3d[0]);

    return lastDetectedObjects;
  }

  Future<List<DetectedObject>> detectObjectsWithBoxes(Uint8List imageBytes) async {
    print('[ObjectDetector] detectObjectsWithBoxes called');
    if (!_isInitialized) return [];

    final inputImage = img.decodeImage(imageBytes)!;
    final resized = img.copyResize(inputImage, width: 640, height: 640);
    final input = ImageUtils.imageToFloat32List(resized, 640, 640);

    final output = List.filled(25200 * 85, 0.0);
    _interpreter.run(input, output);
    final output3d = reshape1DTo3D(output, 1, 25200, 85);

    final detections = <DetectedObject>[];
    for (final detection in output3d[0]) {
      final confidence = detection[4];
      if (confidence > 0.5) {
        final classScores = detection.sublist(5);
        final maxScore = classScores.reduce(max);
        final classId = classScores.indexOf(maxScore);
        final label = _labels[classId];

        final x = detection[0];
        final y = detection[1];
        final w = detection[2];
        final h = detection[3];

        final left = (x - w / 2).clamp(0, 640);
        final top = (y - h / 2).clamp(0, 640);
        final right = (x + w / 2).clamp(0, 640);
        final bottom = (y + h / 2).clamp(0, 640);

        final rect = Rect.fromLTRB(left.toDouble(), top.toDouble(), right.toDouble(), bottom.toDouble());
        detections.add(DetectedObject(label: label, boundingBox: rect));
      }
    }

    return detections;
  }

  List<String> _processOutput(List<List<double>> output) {
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
    return results.toSet().toList();
  }

  void dispose() {
    print('[ObjectDetector] Disposing interpreter');
    _interpreter.close();
  }
}
