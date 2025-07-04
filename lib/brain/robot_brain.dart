import 'dart:async';
import 'dart:typed_data';
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
  bool _isCapturingFrame = false; // <-- Camera guard
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
    if (_isRunning) {
      print('[RobotBrain] Already running');
      return;
    }
    _isRunning = true;
    print('[RobotBrain] Starting voice processor...');
    voiceProcessor.startListening();
    print('[RobotBrain] Starting frame processing...');
    _startFrameProcessing();
  }

  void stop() {
    print('[RobotBrain] Stopping...');
    _isRunning = false;
    _isCapturingFrame = false;
    voiceProcessor.stopListening();
    _frameTimer?.cancel();
  }

  void dispose() {
    print('[RobotBrain] Disposing components...');
    stop();
    cameraController.dispose();
    depthEstimator.dispose();
    objectDetector.dispose();
    voiceProcessor.dispose();
  }

  void _startFrameProcessing() {
    const frameInterval = Duration(milliseconds: 500); // 2 FPS
    _frameTimer = Timer.periodic(frameInterval, (timer) async {
      if (!_isRunning || _isCapturingFrame) return;

      _isCapturingFrame = true; // <-- guard set
      try {
        final frame = await cameraController.takePicture();
        final imageBytes = await frame.readAsBytes();
        await _processFrame(imageBytes);
      } catch (e) {
        debugPrint("[RobotBrain] Frame processing error: $e");
      } finally {
        _isCapturingFrame = false; // <-- guard release
      }
    });
  }

  Future<String?> _handleCommand(Command command) async {
    print('[RobotBrain] Handling command: ${command.type}');
    switch (command.type) {
      case CommandType.detect:
        final imageBytes = await cameraController.takePicture().then((x) => x.readAsBytes());
        final objects = await objectDetector.detectObjects(imageBytes);
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

  Future<void> _processFrame(Uint8List imageBytes) async {
    print('[RobotBrain] Processing frame...');
    final depthMap = await depthEstimator.estimateDepth(imageBytes);
    print('[RobotBrain] Depth estimated');

    await objectDetector.detectObjects(imageBytes);
    print('[RobotBrain] Objects detected');

    final command = voiceProcessor.getCommand();
    print('[RobotBrain] Retrieved command: ${command?.type}');

    String? action;
    if (humanFollower.isActive) {
      print('[RobotBrain] Human follower is active');
      action = await humanFollower.follow(imageBytes, depthMap);
    } else if (command != null) {
      print('[RobotBrain] Using command handler');
      action = await _handleCommand(command);
    } else {
      print('[RobotBrain] Using depth navigator fallback');
      action = depthNavigator.getNavigationAction(depthMap);
    }

    debugPrint("[RobotBrain] Final action: $action");
  }
}
