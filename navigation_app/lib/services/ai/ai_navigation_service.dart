import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../data/datasources/groq_ai_datasource.dart';
import '../../domain/entities/ai_command.dart';
import '../../domain/entities/travel_mode.dart';

/// The single boundary between "text a model produced" and "an action
/// this app will actually perform".
///
/// [GroqAiDataSource] returns whatever JSON Groq responded with. This
/// service is the ONLY place allowed to turn that into an
/// [AiNavigationCommand] — every field is validated against a strict
/// allow-list, unknown/malformed values are dropped rather than trusted,
/// and there is no code path that executes anything the model returns
/// directly (no eval, no dynamic method dispatch by string).
class AiNavigationService {
  AiNavigationService({GroqAiDataSource? dataSource})
      : _dataSource = dataSource ?? GroqAiDataSource();

  final GroqAiDataSource _dataSource;

  static const Set<String> _knownActions = {
    'calculate_route',
    'find_parking',
    'clarification_needed',
    'unsupported',
  };

  static const Set<String> _knownModes = {'driving', 'walking', 'cycling'};

  Future<Result<AiNavigationCommand>> interpret(String userText) async {
    final raw = await _dataSource.parseIntent(userText);
    return raw.when(
      ok: (json) => _validate(json),
      err: (f) => Result.err(f),
    );
  }

  Result<AiNavigationCommand> _validate(Map<String, dynamic> json) {
    final actionRaw = json['action'];
    if (actionRaw is! String || !_knownActions.contains(actionRaw)) {
      // Model returned something outside the allow-list — treat as
      // unsupported rather than guessing what it meant.
      return const Result.ok(
        AiNavigationCommand(action: AiActionType.unsupported),
      );
    }

    final action = switch (actionRaw) {
      'calculate_route' => AiActionType.calculateRoute,
      'find_parking' => AiActionType.findParking,
      'clarification_needed' => AiActionType.clarificationNeeded,
      _ => AiActionType.unsupported,
    };

    final destinationQuery = _safeString(json['destination_query']);
    final modeRaw = json['mode'];
    final mode = (modeRaw is String && _knownModes.contains(modeRaw))
        ? switch (modeRaw) {
            'driving' => TravelMode.driving,
            'walking' => TravelMode.walking,
            'cycling' => TravelMode.cycling,
            _ => null,
          }
        : null;

    final avoidTolls = json['avoid_tolls'] == true;
    final avoidHighways = json['avoid_highways'] == true;
    final arriveByTime = _safeTimeString(json['arrive_by_time']);
    final clarificationQuestion = _safeString(json['clarification_question']);

    if (action == AiActionType.calculateRoute && destinationQuery == null) {
      // A route action without any destination text is not actionable —
      // downgrade to a clarification request rather than silently
      // failing later in the pipeline.
      return const Result.ok(
        AiNavigationCommand(
          action: AiActionType.clarificationNeeded,
          clarificationQuestion: 'Where would you like to go?',
        ),
      );
    }

    return Result.ok(AiNavigationCommand(
      action: action,
      destinationQuery: destinationQuery,
      mode: mode,
      avoidTolls: avoidTolls,
      avoidHighways: avoidHighways,
      arriveByTime: arriveByTime,
      clarificationQuestion: clarificationQuestion,
    ));
  }

  String? _safeString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 200) return null;
    return trimmed;
  }

  /// Accepts only a strict "HH:mm" 24-hour string — anything else is
  /// dropped rather than passed through.
  String? _safeTimeString(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    return match == null ? null : value;
  }
}
