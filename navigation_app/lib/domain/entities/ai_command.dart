import 'travel_mode.dart';

/// The set of structured actions the AI assistant is allowed to request.
///
/// This is a strict allow-list — [AiNavigationCommand] is produced only
/// by validating the raw JSON returned by Groq (see
/// `lib/services/ai/ai_navigation_service.dart`). The app must never
/// execute an arbitrary/unknown action string.
enum AiActionType {
  calculateRoute,
  findParking,
  clarificationNeeded,
  unsupported,
}

/// A validated, structured command derived from a natural-language
/// request. The AI never supplies coordinates, ETAs, or route geometry
/// directly — it only supplies intent, which the app then resolves via
/// the real geocoding/routing/parking services.
class AiNavigationCommand {
  const AiNavigationCommand({
    required this.action,
    this.destinationQuery,
    this.mode,
    this.avoidTolls = false,
    this.avoidHighways = false,
    this.arriveByTime,
    this.clarificationQuestion,
  });

  final AiActionType action;

  /// Free-text place name/address to resolve via geocoding — never a
  /// coordinate pair, since the AI must not invent coordinates.
  final String? destinationQuery;

  final TravelMode? mode;
  final bool avoidTolls;
  final bool avoidHighways;

  /// Local time-of-day the user wants to arrive by, if specified
  /// (e.g. "18:00"). Parsed defensively; invalid values are dropped.
  final String? arriveByTime;

  /// Populated only when [action] is [AiActionType.clarificationNeeded].
  final String? clarificationQuestion;
}
