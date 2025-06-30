import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'object_detector.dart';
import 'navigation_logic.dart';

class HumanFollower {
  final ObjectDetector _objectDetector;
  final DepthNavigator _navigator;
  bool _isActive = false;
  List<int> _lastBoundingBox = [];
  int _lostFrames = 0;
  static const int maxLostFrames = 5;

  HumanFollower(this._objectDetector, this._navigator);

  bool get isActive => _isActive;

  void activate() => _isActive = true;
  void deactivate() {
    _isActive = false;
    _lastBoundingBox = [];
    _lostFrames = 0;
  }

  Future<String> follow(Uint8List imageBytes, List<List<double>> depthMap) async {
    if (!_isActive) return "stop";

    // Decode image
    final image = img.decodeImage(imageBytes)!;
    final bbox = await _detectHuman(image);

    if (bbox.isEmpty) {
      _lostFrames++;
      if (_lostFrames > maxLostFrames) {
        deactivate();
        return "stop";
      }
      return _trackLastKnownPosition(depthMap);
    }

    _lostFrames = 0;
    _lastBoundingBox = bbox;
    return _navigateTowardHuman(bbox, depthMap, image.width, image.height);
  }

  Future<List<int>> _detectHuman(img.Image image) async {
    // Get all detected objects
    final objects = await _objectDetector.detectObjects(image.getBytes());

    // Find the largest person in the frame
    if (!objects.contains('person')) return [];

    // For simplicity, we'll assume center 30% of image as person
    // In real implementation, use actual bounding boxes from detector
    final width = image.width;
    final height = image.height;
    return [
      (width * 0.35).toInt(),  // x1
      (height * 0.35).toInt(), // y1
      (width * 0.65).toInt(),  // x2
      (height * 0.65).toInt()   // y2
    ];
  }

  String _trackLastKnownPosition(List<List<double>> depthMap) {
    if (_lastBoundingBox.isEmpty || depthMap.isEmpty) return "stop";

    // Simple behavior: turn slowly to search
    return _lastDirection == "left" ? "turn_left_slow" : "turn_right_slow";
  }

  String _navigateTowardHuman(
    List<int> bbox,
    List<List<double>> depthMap,
    int imageWidth,
    int imageHeight,
  ) {
    if (depthMap.isEmpty) return "stop";

    // Calculate target center
    final targetCenterX = (bbox[0] + bbox[2]) ~/ 2;
    final targetCenterY = (bbox[1] + bbox[3]) ~/ 2;
    
    // Get depth at target
    final targetDepth = _getDepthAtPoint(depthMap, targetCenterX, targetCenterY);
    
    // Check for safety (cliff/obstacle in path)
    final groundDepth = _getGroundDepth(depthMap, imageHeight);
    if (groundDepth > DepthNavigator.cliffThreshold) {
      return "stop"; // Don't move toward cliff
    }
    
    // Calculate horizontal position relative to center
    final imageCenterX = imageWidth ~/ 2;
    final horizontalOffset = targetCenterX - imageCenterX;
    
    // Determine action based on position and depth
    if (targetDepth > 2.0) {
      // Far away - move forward if clear
      return _navigator.getNavigationAction(depthMap);
    } else if (targetDepth < 1.0) {
      // Too close - stop
      return "stop";
    } else if (horizontalOffset.abs() > imageWidth * 0.2) {
      // Need to adjust horizontal position
      return horizontalOffset < 0 ? "turn_left" : "turn_right";
    } else {
      // Centered and at good distance - move forward
      return "forward";
    }
  }

  double _getDepthAtPoint(List<List<double>> depthMap, int x, int y) {
    if (y >= depthMap.length || x >= depthMap[0].length) return 0.0;
    return depthMap[y][x];
  }

  double _getGroundDepth(List<List<double>> depthMap, int imageHeight) {
    final groundStart = (imageHeight * (1 - DepthNavigator.groundHeightRatio)).toInt();
    double sum = 0;
    int count = 0;
    
    for (int y = groundStart; y < depthMap.length; y++) {
      for (int x = 0; x < depthMap[y].length; x++) {
        sum += depthMap[y][x];
        count++;
      }
    }
    
    return count > 0 ? sum / count : 0.0;
  }

  String get _lastDirection {
    if (_lastBoundingBox.isEmpty) return "left";
    return _lastBoundingBox[0] < _lastBoundingBox[2] ? "left" : "right";
  }
}