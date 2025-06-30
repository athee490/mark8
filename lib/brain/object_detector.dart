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
  final List<String> _labels = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
    'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat',
    'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack',
    'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball',
    'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
    'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
    'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake',
    'chair', 'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop',
    'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
    'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
  ];
  bool _isInitialized = false;
  List<String> lastDetectedObjects = [];

  Future<void> loadModel() async {
    try {
      _interpreter = await TfLiteHelper.loadModel('assets/models/yolov5n.tflite');
      // _labels already initialized above
      _isInitialized = true;
    } catch (e) {
      throw Exception("Failed to load object detector: $e");
    }
  }

  Future<List<String>> detectObjects(Uint8List imageBytes) async {
    if (!_isInitialized) return [];
    
    // Preprocess image
    final inputImage = img.decodeImage(imageBytes)!;
    final resized = img.copyResize(inputImage, width: 640, height: 640);
    final input = ImageUtils.imageToFloat32List(resized, 640, 640);
    
    // Run inference
    final output = List.filled(25200 * 85, 0.0);
    _interpreter.run(input, output);
    final output3d = reshape1DTo3D(output, 1, 25200, 85);
    
    // Process results
    lastDetectedObjects = _processOutput(output3d[0]);
    return lastDetectedObjects;
  }

  List<String> _processOutput(List<List<double>> output) {
    final results = <String>[];
    for (var detection in output) {
      final confidence = detection[4];
      if (confidence > 0.5) {
        final classScores = detection.sublist(5); // class probabilities
        final maxScore = classScores.reduce(max);
        final classId = classScores.indexOf(maxScore);
        results.add(_labels[classId]);
      }
    }
    return results.toSet().toList(); // Return unique objects
  }

  void dispose() {
    _interpreter.close();
  }
}