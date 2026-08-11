import 'package:flutter_tts/flutter_tts.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';

/// Wraps the platform's native text-to-speech engine (`flutter_tts`) for
/// turn-by-turn voice guidance.
///
/// Uses the OS-provided TTS voice — free, offline-capable on most
/// platforms, and requires no additional API key.
class TextToSpeechService {
  TextToSpeechService({FlutterTts? engine}) : _engine = engine ?? FlutterTts() {
    _configure();
  }

  final FlutterTts _engine;
  bool _speaking = false;

  Future<void> _configure() async {
    await _engine.setSpeechRate(0.5);
    await _engine.setPitch(1.0);
    await _engine.setVolume(1.0);
    _engine.setStartHandler(() => _speaking = true);
    _engine.setCompletionHandler(() => _speaking = false);
    _engine.setCancelHandler(() => _speaking = false);
    _engine.setErrorHandler((_) => _speaking = false);
  }

  bool get isSpeaking => _speaking;

  /// Speaks a single navigation instruction (e.g. "In 300 meters, turn
  /// right."). Interrupts any instruction currently being spoken so the
  /// most recent guidance always takes priority.
  Future<Result<void>> speak(String instruction) async {
    try {
      if (_speaking) {
        await _engine.stop();
      }
      await _engine.speak(instruction);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(VoiceFailure(technicalDetail: e.toString()));
    }
  }

  Future<void> stop() => _engine.stop();

  void dispose() {
    _engine.stop();
  }
}
