import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum CommandType { detect, follow, command, question, unknown }

class Command {
  final CommandType type;
  final String? action;
  final String? text;

  Command({required this.type, this.action, this.text});
}

class VoiceProcessor {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final List<Command> _commandQueue = [];
  bool _isListening = false;
  bool _isInitialized = false;

  Future<void> initialize() async {
    _isInitialized = await _speech.initialize();
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
  }

  void startListening() {
    if (!_isInitialized || _isListening) return;
    
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _processSpeech(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
    _isListening = true;
  }

  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }
  }

  void _processSpeech(String text) {
    final lowerText = text.toLowerCase();
    CommandType type = CommandType.unknown;
    String? action;
    
    // Command detection
    if (lowerText.contains("what")) {
      type = CommandType.detect;
    } else if (lowerText.contains("follow") || lowerText.contains("come here")) {
      type = CommandType.follow;
    } else if (_isCommand(lowerText)) {
      type = CommandType.command;
      action = _mapToAction(lowerText);
    } else {
      type = CommandType.question;
    }
    
    _commandQueue.add(Command(type: type, action: action, text: text));
  }

  bool _isCommand(String text) {
    const commands = [
      "go left", "turn left", "go right", "turn right",
      "go straight", "move forward", "stop", "halt"
    ];
    return commands.any(text.contains);
  }

  String _mapToAction(String text) {
    if (text.contains("left")) return "turn_left";
    if (text.contains("right")) return "turn_right";
    if (text.contains("straight") || text.contains("forward")) return "forward";
    if (text.contains("stop") || text.contains("halt")) return "stop";
    return "stop";
  }

  Command? getCommand() {
    if (_commandQueue.isEmpty) return null;
    return _commandQueue.removeAt(0);
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  void dispose() {
    _speech.cancel();
    _tts.stop();
  }
}