import 'dart:typed_data';
import 'dart:ui'; // For Rect
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

  void activate() {
    _isActive = true;
  }

  void deactivate() {
    _isActive = false;
    _lastBoundingBox = [];
    _lostFrames = 0;
  }

  String get _lastDirection {
    if (_lastBoundingBox.isEmpty) return 'left';
    return _lastBoundingBox[0] < _lastBoundingBox[2] ? 'left' : 'right';
  }

  String _trackLastKnownPosition(List<List<double>> depthMap) {
    if (_lastBoundingBox.isEmpty || depthMap.isEmpty) return 'stop';
    return _lastDirection == 'left' ? 'turn_left_slow' : 'turn_right_slow';
  }

  String _navigateTowardHuman(
      List<int> bbox, List<List<double>> depthMap, int imageWidth, int imageHeight) {
    if (depthMap.isEmpty) return 'stop';

    final centerX = (bbox[0] + bbox[2]) ~/ 2;
    final centerY = (bbox[1] + bbox[3]) ~/ 2;
    final targetDepth = _getDepthAtPoint(depthMap, centerX, centerY);
    final groundDepth = _getGroundDepth(depthMap, imageHeight);

    if (groundDepth > 2.0) return 'stop';

    final imageCenterX = imageWidth ~/ 2;
    final horizontalOffset = centerX - imageCenterX;

    if (targetDepth > 2.0) {
      return _navigator.getNavigationAction(depthMap);
    } else if (targetDepth < 1.0) {
      return 'stop';
    } else if (horizontalOffset.abs() > imageWidth * 0.2) {
      return horizontalOffset < 0 ? 'turn_left' : 'turn_right';
    } else {
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
    final groundStart = (imageHeight * 0.8).toInt();
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
    final pngBytes = Uint8List.fromList(img.encodePng(image));
    final detectedObjects = await _objectDetector.detectObjectsWithBoxes(pngBytes);
    for (final obj in detectedObjects) {
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
