class DepthNavigator {
  static const double obstacleThreshold = 1.5;
  static const double cliffThreshold = 2.0;
  static const double groundHeightRatio = 0.2;
  static const double cameraOffsetRatio = 0.2;

  String getNavigationAction(List<List<double>> depthMap) {
    print('[DepthNavigator] getNavigationAction called');
    if (depthMap.isEmpty) {
      print('[DepthNavigator] Empty depth map');
      return "stop";
    }

    final depths = _analyzeDepth(depthMap);
    print('[DepthNavigator] Depths analyzed: $depths');

    // Cliff detection
    if (depths['ground'] != null && depths['ground']! > cliffThreshold) {
      print('[DepthNavigator] Cliff detected');
      if (depths['left'] != null && depths['right'] != null) {
        final action = depths['left']! > depths['right']! ? "turn_left" : "turn_right";
        print('[DepthNavigator] Cliff action: $action');
        return action;
      } else {
        print('[DepthNavigator] Unknown cliff direction');
        return "unknown";
      }
    }

    // Obstacle avoidance
    final maxDir = _findMaxDepthDirection(depths);
    print('[DepthNavigator] Max depth direction: $maxDir');

    if (maxDir == null || depths[maxDir] == null || depths[maxDir]! < obstacleThreshold) {
      print('[DepthNavigator] No clear path, stopping');
      return "stop";
    }

    final action = _directionToAction(maxDir);
    print('[DepthNavigator] Navigation action: $action');
    return action;
  }

  Map<String, double?> _analyzeDepth(List<List<double>> depthMap) {
    print('[DepthNavigator] _analyzeDepth called');
    final height = depthMap.length;
    final width = depthMap[0].length;
    final offset = (width * cameraOffsetRatio).toInt();

    final left = _regionDepth(depthMap, 0, offset + width ~/ 3, 0, height);
    final center = _regionDepth(depthMap, offset + width ~/ 3, offset + 2 * width ~/ 3, 0, height);
    final right = _regionDepth(depthMap, offset + 2 * width ~/ 3, width, 0, height);

    final groundStart = (height * (1 - groundHeightRatio)).toInt();
    final ground = _regionDepth(depthMap, 0, width, groundStart, height);

    final result = {
      'left': left,
      'center': center,
      'right': right,
      'ground': ground,
    };
    print('[DepthNavigator] Depth regions: $result');
    return result;
  }

  double? _regionDepth(List<List<double>> depthMap, int x1, int x2, int y1, int y2) {
    print('[DepthNavigator] _regionDepth: x1=$x1, x2=$x2, y1=$y1, y2=$y2');
    double sum = 0;
    int count = 0;

    for (int y = y1; y < y2; y++) {
      for (int x = x1; x < x2; x++) {
        if (y < depthMap.length && x < depthMap[y].length) {
          sum += depthMap[y][x];
          count++;
        }
      }
    }

    final avg = count > 0 ? sum / count : null;
    print('[DepthNavigator] Region avg: $avg');
    return avg;
  }

  String? _findMaxDepthDirection(Map<String, double?> depths) {
    print('[DepthNavigator] _findMaxDepthDirection called');
    String? maxKey;
    double? maxValue;

    for (final key in ['left', 'center', 'right']) {
      final value = depths[key];
      if (value != null && (maxValue == null || value > maxValue)) {
        maxValue = value;
        maxKey = key;
      }
    }

    print('[DepthNavigator] Max direction: $maxKey');
    return maxKey;
  }

  String _directionToAction(String? direction) {
    print('[DepthNavigator] _directionToAction: direction=$direction');
    switch (direction) {
      case 'left':
        return "turn_left";
      case 'right':
        return "turn_right";
      case 'center':
        return "forward";
      default:
        return "stop";
    }
  }
}
