import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../utils/tflite_helper.dart';
import '../utils/image_utils.dart';

class ObjectDetector {
  late Interpreter _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  List<String> lastDetectedObjects = [];

  Future<void> loadModel() async {
    try {
      _interpreter = await TfLiteHelper.loadModel('assets/models/yolov5n.tflite');
      // Load labels (would be from a labels.txt file in real implementation)
      _labels = ['person', 'car', 'chair', ...]; // Add all COCO classes
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
    final output = List.filled(25200 * 85, 0.0).reshape([1, 25200, 85]);
    _interpreter.run(input, output);
    
    // Process results
    lastDetectedObjects = _processOutput(output[0]);
    return lastDetectedObjects;
  }

  List<String> _processOutput(List<List<double>> output) {
    final results = <String>[];
    for (var detection in output) {
      final confidence = detection[4];
      if (confidence > 0.5) {
        final classId = detection[5].indexOf(detection[5].reduce(max));
        results.add(_labels[classId]);
      }
    }
    return results.toSet().toList(); // Return unique objects
  }

  void dispose() {
    _interpreter.close();
  }
}