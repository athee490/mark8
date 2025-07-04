import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config.dart';
import 'brain/robot_brain.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('[main] Loading .env...');
    await dotenv.load();
    print('[main] .env loaded');
  } catch (e) {
    print('[main] Error loading .env: $e');
  }

  try {
    print('[main] Getting available cameras...');
    cameras = await availableCameras();
    print('[main] Cameras loaded: ${cameras.length}');
  } catch (e) {
    print('[main] Error getting cameras: $e');
  }

  try {
    print('[main] Loading config...');
    await Config.load();
    print('[main] Config loaded');
  } catch (e) {
    print('[main] Error loading config: $e');
  }

  print('[main] Launching app...');
  runApp(const Mark7App());
}

class Mark7App extends StatelessWidget {
  const Mark7App({super.key});

  @override
  Widget build(BuildContext context) {
    print('[Mark7App] Building MaterialApp');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mark 7',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const RobotBrainWidget(),
    );
  }
}

class RobotBrainWidget extends StatefulWidget {
  const RobotBrainWidget({super.key});

  @override
  State<RobotBrainWidget> createState() => _RobotBrainWidgetState();
}

class _RobotBrainWidgetState extends State<RobotBrainWidget> {
  late RobotBrain _brain;
  String _currentDirection = 'none';
  String _lastSpoken = '';

  @override
  void initState() {
    super.initState();
    print('[RobotBrainWidget] initState called');
    _brain = RobotBrain(cameras: cameras); // FIX: pass cameras list, not camera

    // Remove non-existent setters and methods
    // Optionally, you can add listeners or callbacks if RobotBrain exposes them
    _brain.initialize().then((_) {
      print('[RobotBrainWidget] RobotBrain initialized');
      setState(() {});
      // Optionally, start the brain if needed
      _brain.start();
    }).catchError((e, st) {
      print('[RobotBrainWidget] RobotBrain initialization error: $e\n$st');
    });
  }

  @override
  void dispose() {
    print('[RobotBrainWidget] dispose called');
    _brain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('[RobotBrainWidget] build() called');
    return Scaffold(
      appBar: AppBar(title: const Text('Mark 7 AI')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Direction: $_currentDirection'),
          const SizedBox(height: 20),
          Text('Last spoken: $_lastSpoken'),
        ],
      ),
    );
  }
}
