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
    print('[ObjectDetector] Loading model...');
    try {
      _interpreter = await TfLiteHelper.loadModel('assets/models/yolov5n.tflite');
      // _labels already initialized above
      _isInitialized = true;
      print('[ObjectDetector] Model loaded');
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
    
    // Preprocess image
    final inputImage = img.decodeImage(imageBytes)!;
    print('[ObjectDetector] Image decoded: \\${inputImage.width}x\\${inputImage.height}');
    final resized = img.copyResize(inputImage, width: 640, height: 640);
    print('[ObjectDetector] Image resized');
    final input = ImageUtils.imageToFloat32List(resized, 640, 640);
    print('[ObjectDetector] Image converted to float32');
    
    // Run inference
    final output = List.filled(25200 * 85, 0.0);
    _interpreter.run(input, output);
    print('[ObjectDetector] Inference run complete');
    final output3d = reshape1DTo3D(output, 1, 25200, 85);
    print('[ObjectDetector] Output reshaped');
    
    // Process results
    lastDetectedObjects = _processOutput(output3d[0]);
    print('[ObjectDetector] Detected objects: \\${lastDetectedObjects}');
    return lastDetectedObjects;
  }

  List<String> _processOutput(List<List<double>> output) {
    print('[ObjectDetector] Processing output');
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
    print('[ObjectDetector] Processed results: \\${results.toSet().toList()}');
    return results.toSet().toList(); // Return unique objects
  }

  void dispose() {
    print('[ObjectDetector] Disposing interpreter');
    _interpreter.close();
  }
}