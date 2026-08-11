import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';

/// Live transcription state emitted while the microphone is listening.
class SpeechRecognitionUpdate {
  const SpeechRecognitionUpdate({
    required this.text,
    required this.isFinal,
    required this.soundLevel,
  });

  /// Best-guess transcript so far (partial or final).
  final String text;

  /// Whether the platform considers this the final recognized utterance.
  final bool isFinal;

  /// Normalized microphone input level (roughly 0-1), used to drive the
  /// "listening" waveform/pulse animation. `0` when unavailable.
  final double soundLevel;
}

/// Wraps the platform's native speech recognizer (`speech_to_text`) behind
/// a small, app-owned API.
///
/// Uses the device's built-in/free speech-to-text engine — there is no
/// separate paid transcription API involved, per the product's "no
/// backend, no unnecessary third-party services" constraint.
class SpeechToTextService {
  SpeechToTextService({stt.SpeechToText? engine})
      : _engine = engine ?? stt.SpeechToText();

  final stt.SpeechToText _engine;
  bool _initialized = false;

  Future<Result<bool>> initialize() async {
    try {
      _initialized = await _engine.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
      return Result.ok(_initialized);
    } catch (e) {
      return Result.err(VoiceFailure(technicalDetail: e.toString()));
    }
  }

  bool get isAvailable => _initialized && _engine.isAvailable;
  bool get isListening => _engine.isListening;

  /// Starts listening and streams live updates through [onUpdate] until
  /// [stop] is called or the platform detects the end of speech.
  Future<Result<void>> startListening({
    required void Function(SpeechRecognitionUpdate update) onUpdate,
    String localeId = 'en_US',
    Duration pauseFor = const Duration(seconds: 3),
    Duration listenFor = const Duration(seconds: 20),
  }) async {
    if (!_initialized) {
      final init = await initialize();
      if (init.isErr) {
        return init.when(
          ok: (_) => const Result.ok(null),
          err: (f) => Result.err(f),
        );
      }
    }
    if (!isAvailable) {
      return const Result.err(VoiceFailure());
    }

    try {
      await _engine.listen(
        onResult: (result) {
          onUpdate(SpeechRecognitionUpdate(
            text: result.recognizedWords,
            isFinal: result.finalResult,
            soundLevel: 0,
          ));
        },
        onSoundLevelChange: (level) {
          // Normalize the platform's raw decibel-ish value into 0-1 so the
          // UI layer never needs to know the native scale.
          final normalized = (level / 10).clamp(0.0, 1.0);
          onUpdate(SpeechRecognitionUpdate(
            text: _engine.lastRecognizedWords,
            isFinal: false,
            soundLevel: normalized,
          ));
        },
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
      return const Result.ok(null);
    } catch (e) {
      return Result.err(VoiceFailure(technicalDetail: e.toString()));
    }
  }

  Future<void> stop() => _engine.stop();

  Future<void> cancel() => _engine.cancel();

  void dispose() {
    if (_engine.isListening) {
      _engine.cancel();
    }
  }
}
