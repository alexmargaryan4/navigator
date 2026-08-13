import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/location_providers.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../domain/entities/ai_command.dart';
import '../../../domain/entities/along_route_poi.dart';
import '../../../domain/entities/favorite_route.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/repositories/routing_repository.dart';
import '../../navigation/application/trip_controller.dart';

/// UI-facing phase of an AI navigation request.
enum AiRequestPhase {
  idle,
  thinking,
  resolving,
  needsPlaceConfirmation,
  needsClarification,
  done,
  failed,
}

/// What the AI request was ultimately for — lets the sheet decide what
/// to do once a place is confirmed (start a trip vs. add a stop) without
/// re-deriving it from [AiNavigationCommand] itself.
enum AiPendingIntent { newTrip, addStop }

class AiNavigationState {
  const AiNavigationState({
    this.phase = AiRequestPhase.idle,
    this.lastCommand,
    this.clarificationQuestion,
    this.candidates = const [],
    this.pendingIntent,
    this.alongRoutePois = const [],
    this.alongRouteCategory,
    this.failure,
  });

  final AiRequestPhase phase;
  final AiNavigationCommand? lastCommand;
  final String? clarificationQuestion;

  /// Real, already-geocoded candidates from [SearchRepository.searchForAi]
  /// (product spec «Защита от неправильных мест при AI-поиске»). Shown to
  /// the user to pick from whenever more than one plausible match exists
  /// — the app never silently picks one on the user's behalf.
  final List<Place> candidates;
  final AiPendingIntent? pendingIntent;

  /// Real «По пути» results for the AI's most recent along-route search,
  /// sourced entirely from [AlongRouteSearchService] — never fabricated.
  final List<AlongRoutePoi> alongRoutePois;
  final AlongRoutePoiCategory? alongRouteCategory;

  final AppFailure? failure;

  AiNavigationState copyWith({
    AiRequestPhase? phase,
    AiNavigationCommand? lastCommand,
    String? clarificationQuestion,
    List<Place>? candidates,
    AiPendingIntent? pendingIntent,
    bool clearPendingIntent = false,
    List<AlongRoutePoi>? alongRoutePois,
    AlongRoutePoiCategory? alongRouteCategory,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return AiNavigationState(
      phase: phase ?? this.phase,
      lastCommand: lastCommand ?? this.lastCommand,
      clarificationQuestion: clarificationQuestion ?? this.clarificationQuestion,
      candidates: candidates ?? this.candidates,
      pendingIntent:
          clearPendingIntent ? null : (pendingIntent ?? this.pendingIntent),
      alongRoutePois: alongRoutePois ?? this.alongRoutePois,
      alongRouteCategory: alongRouteCategory ?? this.alongRouteCategory,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Bridges natural-language input to the real navigation pipeline
/// (spec «AI Navigator Mode» / «Защита от неправильных мест при
/// AI-поиске»): Groq only ever returns *intent*; this controller is
/// responsible for resolving that intent against real geocoding/routing
/// data before anything reaches the map.
///
/// The AI is never the source of geographic truth. Every destination
/// this controller acts on came from [SearchRepository.searchForAi] —
/// the same hybrid Mapbox+Geoapify pipeline the manual search sheet
/// uses — and when more than one plausible match comes back, the user
/// picks which one, rather than the app guessing.
class AiNavigationController extends AutoDisposeNotifier<AiNavigationState> {
  /// Relative score gap (as a fraction of the top score) above which the
  /// top search candidate is treated as a confident single match and
  /// auto-selected — the user can still open the panel to see the other
  /// candidates via [candidates], this only skips forcing a manual pick.
  static const double _confidentGapRatio = 0.35;

  @override
  AiNavigationState build() => const AiNavigationState();

  Future<void> submit(String userText) async {
    if (userText.trim().isEmpty) return;

    state = state.copyWith(
      phase: AiRequestPhase.thinking,
      clearFailure: true,
      clearPendingIntent: true,
      candidates: const [],
      alongRoutePois: const [],
    );

    final aiService = ref.read(aiNavigationServiceProvider);
    final result = await aiService.interpret(userText);

    await result.when(
      ok: (command) => _handleCommand(command),
      err: (f) async => state = state.copyWith(phase: AiRequestPhase.failed, failure: f),
    );
  }

  Future<void> _handleCommand(AiNavigationCommand command) async {
    state = state.copyWith(lastCommand: command);

    switch (command.action) {
      case AiActionType.clarificationNeeded:
        state = state.copyWith(
          phase: AiRequestPhase.needsClarification,
          clarificationQuestion:
              command.clarificationQuestion ?? 'Could you clarify that?',
        );
        return;

      case AiActionType.unsupported:
        state = state.copyWith(
          phase: AiRequestPhase.failed,
          failure: const AiNavigationFailure(
            technicalDetail: 'unsupported action',
          ),
        );
        return;

      case AiActionType.calculateRoute:
        await _resolveDestination(command, AiPendingIntent.newTrip);
        return;

      case AiActionType.addStop:
        final tripController = ref.read(tripControllerProvider.notifier);
        final tripState = ref.read(tripControllerProvider);
        if (tripState.destination == null) {
          // No trip in progress to add a stop to — fall back to treating
          // it as a fresh destination rather than failing outright.
          await _resolveDestination(command, AiPendingIntent.newTrip);
          return;
        }
        await _resolveDestination(command, AiPendingIntent.addStop);
        return;

      case AiActionType.findParking:
        // Parking-specific resolution is handled by the parking feature;
        // this controller only marks the command resolved so the UI can
        // route the user to Parking with the destination query as a
        // search seed.
        state = state.copyWith(phase: AiRequestPhase.done);
        return;

      case AiActionType.alongRouteSearch:
        await _handleAlongRouteSearch(command);
        return;

      case AiActionType.startFavoriteRoute:
        await _handleStartFavoriteRoute(command);
        return;
    }
  }

  // -------------------------------------------------------------------
  // Destination resolution — the one place coordinates ever enter the
  // pipeline, and only ever from HybridSearchService via searchForAi.
  // -------------------------------------------------------------------

  Future<void> _resolveDestination(
    AiNavigationCommand command,
    AiPendingIntent intent,
  ) async {
    final query = command.destinationQuery;
    if (query == null) {
      state = state.copyWith(
        phase: AiRequestPhase.needsClarification,
        clarificationQuestion: 'Where would you like to go?',
      );
      return;
    }

    state = state.copyWith(phase: AiRequestPhase.resolving);

    final proximity = await _currentProximity();
    final searchRepo = ref.read(searchRepositoryContractProvider);
    final result = await searchRepo.searchForAi(query, proximity: proximity);

    await result.when(
      ok: (places) async {
        if (places.isEmpty) {
          state = state.copyWith(
            phase: AiRequestPhase.failed,
            failure: const GeocodingFailure(),
          );
          return;
        }

        if (_isConfidentTopMatch(places)) {
          await _applyDestination(places.first, command, intent);
          // Keep the rest as candidates so the UI can still offer
          // "not this one?" without a second round trip, per the
          // requirement that alternatives remain visible even when a
          // top match is offered first.
          state = state.copyWith(candidates: places);
          return;
        }

        state = state.copyWith(
          phase: AiRequestPhase.needsPlaceConfirmation,
          candidates: places,
          pendingIntent: intent,
        );
      },
      err: (f) async => state = state.copyWith(phase: AiRequestPhase.failed, failure: f),
    );
  }

  /// Called by the UI once the user has picked (or confirmed) which
  /// search candidate they mean. This is the only path by which a
  /// [Place]'s real coordinates ever reach the trip controller.
  Future<void> confirmPlace(Place place) async {
    final command = state.lastCommand;
    final intent = state.pendingIntent ?? AiPendingIntent.newTrip;
    if (command == null) return;
    await _applyDestination(place, command, intent);
  }

  Future<void> _applyDestination(
    Place place,
    AiNavigationCommand command,
    AiPendingIntent intent,
  ) async {
    final tripController = ref.read(tripControllerProvider.notifier);

    if (intent == AiPendingIntent.addStop) {
      tripController.addStop(place);
      state = state.copyWith(phase: AiRequestPhase.done);
      return;
    }

    tripController.selectDestination(place);
    if (command.mode != null) {
      tripController.setMode(command.mode!);
    }
    tripController.setOptions(RouteOptions(
      avoidTolls: command.avoidTolls,
      avoidHighways: command.avoidHighways,
    ));
    await tripController.calculateRoutes();
    state = state.copyWith(phase: AiRequestPhase.done);
  }

  /// A top match counts as confident when it clearly separates itself
  /// from the next-best candidate — a relative gap, not an absolute
  /// score, since [Place.relevance] is an open-ended ranking signal
  /// rather than a normalized probability (see HybridSearchService).
  bool _isConfidentTopMatch(List<Place> places) {
    if (places.length == 1) return true;
    final top = places[0].relevance;
    final next = places[1].relevance;
    if (top <= 0) return false;
    return (top - next) / top >= _confidentGapRatio;
  }

  Future<GeoPoint?> _currentProximity() async {
    try {
      final sample = await ref.read(lastKnownLocationProvider.future);
      if (sample == null) return null;
      return GeoPoint(latitude: sample.latitude, longitude: sample.longitude);
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------
  // «По пути» — search along the currently active/previewed route.
  // -------------------------------------------------------------------

  Future<void> _handleAlongRouteSearch(AiNavigationCommand command) async {
    final category = command.poiCategory;
    if (category == null) {
      state = state.copyWith(
        phase: AiRequestPhase.needsClarification,
        clarificationQuestion: 'What would you like to find along the way?',
      );
      return;
    }

    final tripState = ref.read(tripControllerProvider);
    final route = tripState.selectedRoute;
    if (route == null) {
      state = state.copyWith(
        phase: AiRequestPhase.failed,
        failure: const AiNavigationFailure(
          technicalDetail: 'along-route search with no active route',
        ),
      );
      return;
    }

    state = state.copyWith(phase: AiRequestPhase.resolving);

    final along = _toAlongRouteCategory(category);

    final service = ref.read(alongRouteSearchServiceProvider);
    final result = await service.searchAlongRoute(route: route, category: along);

    result.when(
      ok: (pois) {
        state = state.copyWith(
          phase: AiRequestPhase.done,
          alongRoutePois: pois,
          alongRouteCategory: along,
        );
      },
      err: (f) => state = state.copyWith(phase: AiRequestPhase.failed, failure: f),
    );
  }

  AlongRoutePoiCategory _toAlongRouteCategory(AiPoiCategory category) => switch (category) {
        AiPoiCategory.parking => AlongRoutePoiCategory.parking,
        AiPoiCategory.gasStation => AlongRoutePoiCategory.gasStation,
        AiPoiCategory.cafe => AlongRoutePoiCategory.cafe,
        AiPoiCategory.restaurant => AlongRoutePoiCategory.restaurant,
        AiPoiCategory.shop => AlongRoutePoiCategory.shop,
        AiPoiCategory.evCharging => AlongRoutePoiCategory.evCharging,
      };

  // -------------------------------------------------------------------
  // Favorite routes — matched against the user's own saved data only;
  // the AI never guesses an address for these, only which saved route
  // (by name) the phrase was most likely referring to.
  // -------------------------------------------------------------------

  Future<void> _handleStartFavoriteRoute(AiNavigationCommand command) async {
    final query = command.favoriteRouteQuery?.trim().toLowerCase();
    if (query == null || query.isEmpty) {
      state = state.copyWith(
        phase: AiRequestPhase.needsClarification,
        clarificationQuestion: 'Which saved route would you like to start?',
      );
      return;
    }

    state = state.copyWith(phase: AiRequestPhase.resolving);

    final repo = ref.read(favoriteRoutesRepositoryProvider);
    final result = await repo.getAll();

    await result.when(
      ok: (routes) async {
        final match = _bestFavoriteRouteMatch(routes, query);
        if (match == null) {
          state = state.copyWith(
            phase: AiRequestPhase.failed,
            failure: const AiNavigationFailure(
              technicalDetail: 'no matching favorite route',
            ),
          );
          return;
        }

        final tripController = ref.read(tripControllerProvider.notifier);
        await tripController.startTripFromEndpoints(
          destinationPlace: match.destination.toPlace(),
          stopPlaces: match.stops.map((s) => s.toPlace()).toList(),
          mode: match.mode,
        );
        state = state.copyWith(phase: AiRequestPhase.done);
      },
      err: (f) async => state = state.copyWith(phase: AiRequestPhase.failed, failure: f),
    );
  }

  /// Simple, local, deterministic name matching against the user's own
  /// saved routes — never a guess at a real-world place. Prefers an
  /// exact label match, then falls back to substring containment either
  /// way, so "работа" matches a route labeled "Дом → Работа".
  FavoriteRoute? _bestFavoriteRouteMatch(List<FavoriteRoute> routes, String query) {
    if (routes.isEmpty) return null;

    for (final r in routes) {
      if (r.label.toLowerCase() == query) return r;
    }
    for (final r in routes) {
      final label = r.label.toLowerCase();
      if (label.contains(query) || query.contains(label)) return r;
    }
    for (final r in routes) {
      if (r.destination.name.toLowerCase().contains(query)) return r;
    }
    return null;
  }

  void reset() => state = const AiNavigationState();
}

final aiNavigationControllerProvider =
    AutoDisposeNotifierProvider<AiNavigationController, AiNavigationState>(
  AiNavigationController.new,
);
