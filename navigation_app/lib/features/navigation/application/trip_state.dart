import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../domain/repositories/routing_repository.dart';

/// The lifecycle stage of a trip, from an idle map through to active
/// turn-by-turn guidance (product spec §20-23).
enum TripPhase {
  /// No destination selected — plain map browsing.
  idle,

  /// A destination has been picked (search result, POI, or AI command)
  /// and its info card is showing, but routes haven't been requested yet.
  destinationSelected,

  /// Routes have been calculated and are shown for the user to review /
  /// pick between alternatives, before committing to navigation.
  routePreview,

  /// Turn-by-turn navigation is actively running.
  navigating,
}

/// The single source of truth for "what trip is the user planning or
/// running right now" — shared by the map, route-preview sheet, and
/// active-navigation UI so they always agree on state.
class TripState {
  const TripState({
    this.phase = TripPhase.idle,
    this.destination,
    this.mode = TravelMode.driving,
    this.options = const RouteOptions(),
    this.routes = const [],
    this.selectedRouteId,
    this.isCalculatingRoute = false,
    this.failure,
    this.currentStepIndex = 0,
    this.remainingDistanceMeters,
    this.remainingDurationSeconds,
    this.isFollowingUser = true,
  });

  final TripPhase phase;
  final Place? destination;
  final TravelMode mode;
  final RouteOptions options;
  final List<NavRoute> routes;
  final String? selectedRouteId;
  final bool isCalculatingRoute;
  final AppFailure? failure;

  /// Index into the active route's [NavRoute.steps] for the maneuver
  /// currently being guided.
  final int currentStepIndex;

  /// Live-updating remaining distance/time during active navigation,
  /// recomputed from GPS progress against the active route — never
  /// re-fabricated, only derived from real route geometry.
  final double? remainingDistanceMeters;
  final double? remainingDurationSeconds;

  /// Whether the map camera should keep following the user (spec §52) —
  /// set to `false` the moment the user manually pans the map.
  final bool isFollowingUser;

  NavRoute? get selectedRoute {
    if (routes.isEmpty) return null;
    if (selectedRouteId == null) {
      return routes.where((r) => r.isPrimary).firstOrNull ?? routes.first;
    }
    for (final r in routes) {
      if (r.id == selectedRouteId) return r;
    }
    return routes.first;
  }

  bool get isActive => phase == TripPhase.navigating;

  TripState copyWith({
    TripPhase? phase,
    Place? destination,
    bool clearDestination = false,
    TravelMode? mode,
    RouteOptions? options,
    List<NavRoute>? routes,
    String? selectedRouteId,
    bool clearSelectedRouteId = false,
    bool? isCalculatingRoute,
    AppFailure? failure,
    bool clearFailure = false,
    int? currentStepIndex,
    double? remainingDistanceMeters,
    double? remainingDurationSeconds,
    bool? isFollowingUser,
  }) {
    return TripState(
      phase: phase ?? this.phase,
      destination: clearDestination ? null : (destination ?? this.destination),
      mode: mode ?? this.mode,
      options: options ?? this.options,
      routes: routes ?? this.routes,
      selectedRouteId:
          clearSelectedRouteId ? null : (selectedRouteId ?? this.selectedRouteId),
      isCalculatingRoute: isCalculatingRoute ?? this.isCalculatingRoute,
      failure: clearFailure ? null : (failure ?? this.failure),
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingDurationSeconds:
          remainingDurationSeconds ?? this.remainingDurationSeconds,
      isFollowingUser: isFollowingUser ?? this.isFollowingUser,
    );
  }

  static const idleState = TripState();
}

/// Small null-safe convenience used by [TripState.selectedRoute].
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Placeholder for a resolved origin point — kept here rather than in
/// [TripState] since origin always tracks live GPS, not trip selection.
class TripOrigin {
  const TripOrigin(this.point);
  final GeoPoint point;
}
