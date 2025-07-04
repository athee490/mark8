import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'object_detector.dart';
import 'navigation_logic.dart';

class DetectedObject {
  final String label;
  final img.Rectangle boundingBox;

  DetectedObject({required this.label, required this.boundingBox});
}

class HumanFollower {
  final ObjectDetector _objectDetector;
  final DepthNavigator _navigator;
  bool _isActive = false;
  List<int> _lastBoundingBox = [];
  int _lostFrames = 0;
  static const int maxLostFrames = 5;

  HumanFollower(this._objectDetector, this._navigator);

  bool get isActive {
    print('[HumanFollower] isActive: $_isActive');
    return _isActive;
  }

  void activate() {
    print('[HumanFollower] activate called');
    _isActive = true;
  }

  void deactivate() {
    print('[HumanFollower] deactivate called');
    _isActive = false;
    _lastBoundingBox = [];
    _lostFrames = 0;
  }

  String get _lastDirection {
    if (_lastBoundingBox.isEmpty) return 'left';
    final xMin = _lastBoundingBox[0];
    final xMax = _lastBoundingBox[2];
    return xMin < xMax ? 'left' : 'right';
  }

  String _trackLastKnownPosition(List<List<double>> depthMap) {
    print('[HumanFollower] _trackLastKnownPosition called');
    if (_lastBoundingBox.isEmpty || depthMap.isEmpty) {
      print('[HumanFollower] No last bounding box or empty depth map');
      return 'stop';
    }
    final dir = _lastDirection;
    print('[HumanFollower] Last direction: $dir');
    return dir == 'left' ? 'turn_left_slow' : 'turn_right_slow';
  }

  String _navigateTowardHuman(
      List<int> bbox, List<List<double>> depthMap, int imageWidth, int imageHeight) {
    print('[HumanFollower] _navigateTowardHuman called');
    if (depthMap.isEmpty) return 'stop';

    final centerX = (bbox[0] + bbox[2]) ~/ 2;
    final centerY = (bbox[1] + bbox[3]) ~/ 2;
    final targetDepth = _getDepthAtPoint(depthMap, centerX, centerY);
    final groundDepth = _getGroundDepth(depthMap, imageHeight);

    if (groundDepth > 2.0) {
      print('[HumanFollower] Cliff detected');
      return 'stop';
    }

    final imageCenterX = imageWidth ~/ 2;
    final horizontalOffset = centerX - imageCenterX;

    if (targetDepth > 2.0) {
      print('[HumanFollower] Far away, moving forward');
      return _navigator.getNavigationAction(depthMap);
    } else if (targetDepth < 1.0) {
      print('[HumanFollower] Too close, stopping');
      return 'stop';
    } else if (horizontalOffset.abs() > imageWidth * 0.2) {
      print('[HumanFollower] Adjusting horizontal position');
      return horizontalOffset < 0 ? 'turn_left' : 'turn_right';
    } else {
      print('[HumanFollower] Centered and at good distance, moving forward');
      return 'forward';
    }
  }

  double _getDepthAtPoint(List<List<double>> depthMap, int x, int y) {
    if (y < 0 || y >= depthMap.length || x < 0 || x >= depthMap[0].length) {
      return 0.0;
    }
    return depthMap[y][x];
  }

  double _getGroundDepth(List<List<double>> depthMap, int imageHeight) {
    final groundStart = (imageHeight * (1.0 - 0.2)).toInt(); // 0.2 from groundHeightRatio
    double sum = 0.0;
    int count = 0;

    for (int y = groundStart; y < depthMap.length; y++) {
      for (int x = 0; x < depthMap[y].length; x++) {
        sum += depthMap[y][x];
        count++;
      }
    }
    return count > 0 ? sum / count : 0.0;
  }

  Future<List<int>> _detectHuman(img.Image image) async {
    print('[HumanFollower] _detectHuman called');
    final pngBytes = Uint8List.fromList(img.encodePng(image));
    final detectedObjects = await _objectDetector.detectObjectsWithBoxes(pngBytes);
    for (final obj in detectedObjects) {
      print('[HumanFollower] Checking object: label=${obj.label}, bbox=${obj.boundingBox}');
      if (obj.label == 'person') {
        final box = obj.boundingBox;
        return [
          box.left.toInt(),
          box.top.toInt(),
          box.right.toInt(),
          box.bottom.toInt(),
        ];
      }
    }
    return [];
  }

  Future<String> follow(Uint8List imageBytes, List<List<double>> depthMap) async {
    print('[HumanFollower] follow called');
    if (!_isActive) return 'stop';

    final image = img.decodeImage(imageBytes);
    if (image == null) return 'stop';

    final bbox = await _detectHuman(image);
    if (bbox.isEmpty) {
      _lostFrames++;
      if (_lostFrames > maxLostFrames) {
        deactivate();
        return 'stop';
      }
      return _trackLastKnownPosition(depthMap);
    }

    _lostFrames = 0;
    _lastBoundingBox = bbox;
    return _navigateTowardHuman(bbox, depthMap, image.width, image.height);
  }
}
