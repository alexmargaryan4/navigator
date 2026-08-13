import 'travel_mode.dart';

/// The set of structured actions the AI assistant is allowed to request.
///
/// This is a strict allow-list — [AiNavigationCommand] is produced only
/// by validating the raw JSON returned by Groq (see
/// `lib/services/ai/ai_navigation_service.dart`). The app must never
/// execute an arbitrary/unknown action string.
///
/// Every action here is *intent only* — none of them carry coordinates.
/// [AiActionType.calculateRoute] and [AiActionType.addStop] carry a
/// [AiNavigationCommand.destinationQuery] that must be resolved through
/// the real search pipeline (see `AiNavigationController`) before it is
/// ever used for a marker, camera move, or route request (product spec
/// «AI никогда не должен самостоятельно придумывать координаты места»).
enum AiActionType {
  calculateRoute,
  addStop,
  findParking,

  /// Find a category of POI along the *currently active* route (product
  /// spec «По пути», e.g. «По пути найди заправку»). Only valid when a
  /// trip is already being navigated — see
  /// `AiNavigationController._handleCommand`.
  alongRouteSearch,

  /// Launch a previously saved favorite route by name (product spec
  /// «Избранные маршруты», e.g. «Поехали на работу» matching a saved
  /// "Дом → Работа"). Matching happens against the user's own saved
  /// data locally — the AI only supplies which one it thinks was meant.
  startFavoriteRoute,
  clarificationNeeded,
  unsupported,
}

/// The «По пути» POI category the AI believes the user asked for, when
/// [AiActionType.alongRouteSearch] is returned. Kept as a strict
/// allow-list mirroring [AlongRoutePoiCategory] so an unrecognized
/// string can never reach the search call.
enum AiPoiCategory { parking, gasStation, cafe, restaurant, shop, evCharging }

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
    this.poiCategory,
    this.favoriteRouteQuery,
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

  /// Populated only when [action] is [AiActionType.alongRouteSearch].
  final AiPoiCategory? poiCategory;

  /// Free-text name to match against the user's saved favorite routes
  /// when [action] is [AiActionType.startFavoriteRoute] — never an id,
  /// since the AI has no access to the user's saved data.
  final String? favoriteRouteQuery;
}
