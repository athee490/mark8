import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config.dart';
import 'brain/robot_brain.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('Loading .env...');
    await dotenv.load();
    print('.env loaded');
  } catch (e) {
    print('Error loading .env: $e');
  }
  try {
    print('Getting available cameras...');
    cameras = await availableCameras();
    print('Cameras loaded: \\${cameras.length}');
  } catch (e) {
    print('Error getting cameras: $e');
  }
  try {
    print('Loading config...');
    await Config.load();
    print('Config loaded');
  } catch (e) {
    print('Error loading config: $e');
  }
  runApp(const Mark7App());
}

class Mark7App extends StatelessWidget {
  const Mark7App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mark7 Robot',
      theme: ThemeData.dark(),
      home: CameraScreen(cameras: cameras),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late RobotBrain robotBrain;
  bool _isRunning = false;
  String _status = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initRobot();
  }

  Future<void> _initRobot() async {
    try {
      print('Initializing RobotBrain...');
      robotBrain = RobotBrain(cameras: widget.cameras);
      await robotBrain.initialize();
      print('RobotBrain initialized');
      setState(() => _status = "Ready");
    } catch (e, st) {
      print('Error initializing RobotBrain: $e\\n$st');
      setState(() => _status = "Error: $e");
    }
  }

  void _toggleOperation() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        try {
          robotBrain.start();
          _status = "Running";
        } catch (e) {
          print('Error starting RobotBrain: $e');
          _status = "Error: $e";
        }
      } else {
        try {
          robotBrain.stop();
          _status = "Stopped";
        } catch (e) {
          print('Error stopping RobotBrain: $e');
          _status = "Error: $e";
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mark7 Robot')),
      body: Column(
        children: [
          Expanded(
            child: _isRunning
                ? CameraPreview(robotBrain.cameraController)
                : const Center(child: Icon(Icons.android, size: 100)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_status, style: Theme.of(context).textTheme.headlineSmall),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleOperation,
        child: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
      ),
    );
  }

  @override
  void dispose() {
    try {
      robotBrain.dispose();
    } catch (e) {
      print('Error disposing RobotBrain: $e');
    }
    super.dispose();
  }
}