import 'dart:typed_data';
import 'dart:math';
import 'dart:ui'; // for Rect
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

  final List<String> _labels = [
    'person','bicycle','car','motorcycle','airplane','bus','train','truck','boat',
    'traffic light','fire hydrant','stop sign','parking meter','bench','bird','cat',
    'dog','horse','sheep','cow','elephant','bear','zebra','giraffe','backpack',
    'umbrella','handbag','tie','suitcase','frisbee','skis','snowboard','sports ball',
    'kite','baseball bat','baseball glove','skateboard','surfboard','tennis racket',
    'bottle','wine glass','cup','fork','knife','spoon','bowl','banana','apple',
    'sandwich','orange','broccoli','carrot','hot dog','pizza','donut','cake','chair',
    'couch','potted plant','bed','dining table','toilet','tv','laptop','mouse','remote',
    'keyboard','cell phone','microwave','oven','toaster','sink','refrigerator','book',
    'clock','vase','scissors','teddy bear','hair drier','toothbrush'
  ];

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
    print('[ObjectDetector] detectObjects called');
    if (!_isInitialized) return [];

    final inputImage = img.decodeImage(imageBytes);
    if (inputImage == null) {
      print('[ObjectDetector] Failed to decode image');
      return [];
    }

    final resized = img.copyResize(inputImage, width: 640, height: 640);
    final input = ImageUtils.imageToFloat32List(resized, 640, 640);
    final output = List<double>.filled(25200 * 85, 0.0);

    try {
      _interpreter.run(input, output);
    } catch (e) {
      print('[ObjectDetector] Inference error: $e');
      return [];
    }

    final output3d = reshape1DTo3D(output, 1, 25200, 85);
    final labels = _processOutput(output3d[0]);
    print('[ObjectDetector] Detected labels: $labels');
    return labels;
  }

  Future<List<DetectedObject>> detectObjectsWithBoxes(Uint8List imageBytes) async {
    print('[ObjectDetector] detectObjectsWithBoxes called');
    if (!_isInitialized) return [];

    final inputImage = img.decodeImage(imageBytes);
    if (inputImage == null) return [];

    final resized = img.copyResize(inputImage, width: 640, height: 640);
    final input = ImageUtils.imageToFloat32List(resized, 640, 640);
    final output = List<double>.filled(25200 * 85, 0.0);

    try {
      _interpreter.run(input, output);
    } catch (e) {
      print('[ObjectDetector] Inference error: $e');
      return [];
    }

    final output3d = reshape1DTo3D(output, 1, 25200, 85);
    final detections = <DetectedObject>[];
    for (final det in output3d[0]) {
      final confidence = det[4];
      if (confidence <= 0.5) continue;

      final classScores = det.sublist(5);
      final maxScore = classScores.reduce(max);
      final classId = classScores.indexOf(maxScore);
      final label = _labels[classId];

      final x = det[0], y = det[1], w = det[2], h = det[3];
      final left   = (x - w / 2).clamp(0.0, 640.0);
      final top    = (y - h / 2).clamp(0.0, 640.0);
      final right  = (x + w / 2).clamp(0.0, 640.0);
      final bottom = (y + h / 2).clamp(0.0, 640.0);

      final box = Rect.fromLTRB(left, top, right, bottom);
      detections.add(DetectedObject(label: label, boundingBox: box));
    }
    print('[ObjectDetector] Detected objects with boxes: ${detections.length}');
    return detections;
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
    print('[ObjectDetector] Disposing interpreter');
    _interpreter.close();
  }
}
