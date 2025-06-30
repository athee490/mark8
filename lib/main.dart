import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config.dart';
import 'brain/robot_brain.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  cameras = await availableCameras();
  await Config.load();
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
    robotBrain = RobotBrain(cameras: widget.cameras);
    await robotBrain.initialize();
    setState(() => _status = "Ready");
  }

  void _toggleOperation() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        robotBrain.start();
        _status = "Running";
      } else {
        robotBrain.stop();
        _status = "Stopped";
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
    robotBrain.dispose();
    super.dispose();
  }
}