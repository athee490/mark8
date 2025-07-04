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
    try {
      print('[RobotBrain] Initializing camera controller...');
      cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await cameraController.initialize();
      print('[RobotBrain] Camera initialized');

      print('[RobotBrain] Initializing depth estimator...');
      depthEstimator = DepthEstimator();
      await depthEstimator.loadModel();
      print('[RobotBrain] Depth estimator loaded');

      print('[RobotBrain] Initializing object detector...');
      objectDetector = ObjectDetector();
      await objectDetector.loadModel();
      print('[RobotBrain] Object detector loaded');

      print('[RobotBrain] Initializing voice processor...');
      voiceProcessor = VoiceProcessor();
      await voiceProcessor.initialize();
      print('[RobotBrain] Voice processor initialized');

      print('[RobotBrain] Initializing depth navigator...');
      depthNavigator = DepthNavigator();
      print('[RobotBrain] Depth navigator initialized');

      print('[RobotBrain] Initializing human follower...');
      humanFollower = HumanFollower(objectDetector, depthNavigator);
      print('[RobotBrain] Human follower initialized');

      print('[RobotBrain] Initializing QA system...');
      qaSystem = QASystem();
      await qaSystem.loadDatabase();
      print('[RobotBrain] QA system initialized');
    } catch (e, st) {
      print('[RobotBrain] Initialization error: $e\n$st');
      rethrow;
    }
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

  Future<String?> _handleCommand(Command command) async {
    switch (command.type) {
      case CommandType.detect:
        final objects = objectDetector.lastDetectedObjects;
        if (objects.isNotEmpty) {
          voiceProcessor.speak("I see ${objects.join(', ')}");
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
      action = await _handleCommand(command);
    } else {
      action = depthNavigator.getNavigationAction(depthMap);
    }
    debugPrint("Action: $action");
  }
}