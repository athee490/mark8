import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'depth_estimator.dart';
import 'object_detector.dart';
import 'voice_processor.dart';
import 'navigation_logic.dart';
import 'human_follower.dart';
import 'qa_system.dart';

class RobotBrain {
  final List<CameraDescription> cameras;
  late CameraController cameraController;
  late DepthEstimator depthEstimator;
  late ObjectDetector objectDetector;
  late VoiceProcessor voiceProcessor;
  late DepthNavigator depthNavigator;
  late HumanFollower humanFollower;
  late QASystem qaSystem;
  bool _isRunning = false;
  Timer? _frameTimer;

  RobotBrain({required this.cameras});

  Future<void> initialize() async {
    cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await cameraController.initialize();

    depthEstimator = DepthEstimator();
    await depthEstimator.loadModel();

    objectDetector = ObjectDetector();
    await objectDetector.loadModel();

    voiceProcessor = VoiceProcessor();
    await voiceProcessor.initialize();

    depthNavigator = DepthNavigator();
    humanFollower = HumanFollower(objectDetector, depthNavigator);
    qaSystem = QASystem();
    await qaSystem.loadDatabase();
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    voiceProcessor.startListening();
    _startFrameProcessing();
  }

  void stop() {
    _isRunning = false;
    voiceProcessor.stopListening();
    _frameTimer?.cancel();
  }

  void dispose() {
    stop();
    cameraController.dispose();
    depthEstimator.dispose();
    objectDetector.dispose();
    voiceProcessor.dispose();
  }

  void _startFrameProcessing() {
    const frameInterval = Duration(milliseconds: 500); // 2 FPS
    _frameTimer = Timer.periodic(frameInterval, (timer) async {
      if (!_isRunning) return;
      try {
        final frame = await cameraController.takePicture();
        final imageBytes = await frame.readAsBytes();
        await _processFrame(imageBytes);
      } catch (e) {
        debugPrint("Frame processing error: $e");
      }
    });
  }

  Future<void> _processFrame(Uint8List imageBytes) async {
    // Depth estimation
    final depthMap = await depthEstimator.estimateDepth(imageBytes);
    // Object detection
    await objectDetector.detectObjects(imageBytes);
    // Voice command processing
    final command = voiceProcessor.getCommand();
    // Navigation logic
    String? action;
    if (humanFollower.isActive) {
      action = await humanFollower.follow(imageBytes, depthMap);
    } else if (command != null) {
      action = _handleCommand(command);
    } else {
      action = depthNavigator.getNavigationAction(depthMap);
    }
    debugPrint("Action: $action");
  }

  String? _handleCommand(Command command) {
    switch (command.type) {
      case CommandType.detect:
        final objects = objectDetector.lastDetectedObjects;
        if (objects.isNotEmpty) {
          voiceProcessor.speak("I see ${objects.join(', ')}");
        } else {
          voiceProcessor.speak("I don't see any objects");
        }
        return null;
      case CommandType.follow:
        humanFollower.activate();
        voiceProcessor.speak("Starting to follow you");
        return "follow";
      case CommandType.command:
        humanFollower.deactivate();
        return command.action;
      case CommandType.question:
        String answer = await qaSystem.answer(command.text ?? "");
        voiceProcessor.speak(answer);
        return null;
      default:
        return null;
    }
  }
}