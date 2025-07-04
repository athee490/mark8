import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'object_detector.dart';
import 'navigation_logic.dart';

class HumanFollower {
  final ObjectDetector _objectDetector;
  final DepthNavigator _navigator;
  bool _isActive = false;
  List<int> _lastBoundingBox = <int>[];
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
    _lastBoundingBox = <int>[];
    _lostFrames = 0;
  }

  String get _lastDirection {
    if (_lastBoundingBox.isEmpty) return 'left';
    // _lastBoundingBox: [xMin, yMin, xMax, yMax]
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
    if (depthMap.isEmpty) {
      print('[HumanFollower] Empty depth map');
      return 'stop';
    }

    final centerX = (bbox[0] + bbox[2]) ~/ 2;
    final centerY = (bbox[1] + bbox[3]) ~/ 2;
    final targetDepth = _getDepthAtPoint(depthMap, centerX, centerY);
    final groundDepth = _getGroundDepth(depthMap, imageHeight);

    // Use instance fields in case cliffThreshold/groundHeightRatio are not static
    if (groundDepth > _navigator.cliffThreshold) {
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
    print('[HumanFollower] _getDepthAtPoint: x=$x, y=$y');
    if (y < 0 || y >= depthMap.length || x < 0 || x >= depthMap[0].length) {
      print('[HumanFollower] _getDepthAtPoint: out of bounds');
      return 0.0;
    }
    final value = depthMap[y][x];
    print('[HumanFollower] _getDepthAtPoint: value=$value');
    return value;
  }

  double _getGroundDepth(List<List<double>> depthMap, int imageHeight) {
    final groundStart = (imageHeight * (1.0 - _navigator.groundHeightRatio)).toInt();
    print('[HumanFollower] _getGroundDepth: groundStart=$groundStart');
    double sum = 0.0;
    int count = 0;
    for (int y = groundStart; y < depthMap.length; y++) {
      for (int x = 0; x < depthMap[y].length; x++) {
        sum += depthMap[y][x];
        count++;
      }
    }
    final avg = count > 0 ? sum / count : 0.0;
    print('[HumanFollower] _getGroundDepth: avg=$avg, count=$count');
    return avg;
  }

  /// Detects a human and returns the bounding box [xMin, yMin, xMax, yMax].
  Future<List<int>> _detectHuman(img.Image image) async {
    print('[HumanFollower] _detectHuman called');
    final pngBytes = Uint8List.fromList(img.encodePng(image));
    final detectedObjects = await _objectDetector.detectObjects(pngBytes);
    print('[HumanFollower] Detected objects: $detectedObjects');

    for (final obj in detectedObjects) {
      print('[HumanFollower] Checking object: label=${obj.label}, bbox=${obj.boundingBox}');
      if (obj.label == 'person') {
        final box = obj.boundingBox;
        final bbox = [
          box.left.toInt(),
          box.top.toInt(),
          box.right.toInt(),
          box.bottom.toInt(),
        ];
        print('[HumanFollower] Returning bbox: $bbox');
        return bbox;
      }
    }

    print('[HumanFollower] No person detected');
    return <int>[];
  }

  /// Processes the image and depth map, returning a navigation command.
  Future<String> follow(
      Uint8List imageBytes, List<List<double>> depthMap) async {
    print('[HumanFollower] follow called');
    if (!_isActive) {
      print('[HumanFollower] Not active');
      return 'stop';
    }

    final image = img.decodeImage(imageBytes);
    if (image == null) {
      print('[HumanFollower] Failed to decode image');
      return 'stop';
    }
    print('[HumanFollower] Image decoded: ${image.width}x${image.height}');

    final bbox = await _detectHuman(image);
    print('[HumanFollower] Bounding box: $bbox');

    if (bbox.isEmpty) {
      _lostFrames++;
      print('[HumanFollower] Human lost, lostFrames=$_lostFrames');
      if (_lostFrames > maxLostFrames) {
        deactivate();
        print('[HumanFollower] Max lost frames reached, deactivating');
        return 'stop';
      }
      return _trackLastKnownPosition(depthMap);
    }

    _lostFrames = 0;
    _lastBoundingBox = List<int>.from(bbox);
    return _navigateTowardHuman(
        _lastBoundingBox, depthMap, image.width, image.height);
  }
}
