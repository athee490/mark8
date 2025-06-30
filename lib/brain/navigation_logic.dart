class DepthNavigator {
  static const double obstacleThreshold = 1.5;
  static const double cliffThreshold = 2.0;
  static const double groundHeightRatio = 0.2;
  static const double cameraOffsetRatio = 0.2;

  String getNavigationAction(List<List<double>> depthMap) {
    if (depthMap.isEmpty) return "stop";
    
    final depths = _analyzeDepth(depthMap);
    
    // Cliff detection
    if (depths['ground'] != null && depths['ground']! > cliffThreshold) {
      if (depths['left'] != null && depths['right'] != null) {
        return depths['left']! > depths['right']! ? "turn_left" : "turn_right";
      } else {
        return "unknown";
      }
    }
    
    // Obstacle avoidance
    final maxDir = _findMaxDepthDirection(depths);
    if (maxDir == null || depths[maxDir] == null || depths[maxDir]! < obstacleThreshold) return "stop";
    
    return _directionToAction(maxDir);
  }

  Map<String, double?> _analyzeDepth(List<List<double>> depthMap) {
    final height = depthMap.length;
    final width = depthMap[0].length;
    final offset = (width * cameraOffsetRatio).toInt();
    
    // Regions
    final left = _regionDepth(depthMap, 0, offset + width ~/ 3, 0, height);
    final center = _regionDepth(depthMap, offset + width ~/ 3, offset + 2 * width ~/ 3, 0, height);
    final right = _regionDepth(depthMap, offset + 2 * width ~/ 3, width, 0, height);
    
    // Ground detection
    final groundStart = (height * (1 - groundHeightRatio)).toInt();
    final ground = _regionDepth(depthMap, 0, width, groundStart, height);
    
    return {
      'left': left,
      'center': center,
      'right': right,
      'ground': ground,
    };
  }

  double? _regionDepth(List<List<double>> depthMap, int x1, int x2, int y1, int y2) {
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
    
    return count > 0 ? sum / count : null;
  }

  String? _findMaxDepthDirection(Map<String, double?> depths) {
    String? maxKey;
    double? maxValue;
    for (final key in ['left', 'center', 'right']) {
      final value = depths[key];
      if (value != null && (maxValue == null || value > maxValue)) {
        maxValue = value;
        maxKey = key;
      }
    }
    return maxKey;
  }

  String _directionToAction(String? direction) {
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