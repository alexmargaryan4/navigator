import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';
import '../../core/permissions/location_permission_handler.dart';
import '../../core/location/location_tracker.dart';
import '../../data/datasources/groq_ai_datasource.dart';
import '../../data/datasources/mapbox_parking_datasource.dart';
import '../../data/datasources/mapbox_routing_datasource.dart';
import '../../data/datasources/mapbox_search_datasource.dart';
import '../../data/repositories/parking_repository_impl.dart';
import '../../data/repositories/routing_repository_impl.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../data/repositories/traffic_repository_impl.dart';
import '../../domain/repositories/parking_repository.dart';
import '../../domain/repositories/routing_repository.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/repositories/traffic_repository.dart';
import '../../services/ai/ai_navigation_service.dart';
import '../../services/voice/speech_to_text_service.dart';
import '../../services/voice/text_to_speech_service.dart';

/// Single, app-wide [ApiClient] instance — every datasource shares one
/// underlying [http.Client] rather than creating its own.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

// ---------------------------------------------------------------------------
// Datasources
// ---------------------------------------------------------------------------

final mapboxSearchDataSourceProvider = Provider<MapboxSearchDataSource>(
  (ref) => MapboxSearchDataSource(client: ref.watch(apiClientProvider)),
);

final mapboxRoutingDataSourceProvider = Provider<MapboxRoutingDataSource>(
  (ref) => MapboxRoutingDataSource(client: ref.watch(apiClientProvider)),
);

final mapboxParkingDataSourceProvider = Provider<MapboxParkingDataSource>(
  (ref) => MapboxParkingDataSource(client: ref.watch(apiClientProvider)),
);

final groqAiDataSourceProvider = Provider<GroqAiDataSource>(
  (ref) => GroqAiDataSource(client: ref.watch(apiClientProvider)),
);

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final searchRepositoryProvider = Provider<SearchRepositoryImpl>(
  (ref) => SearchRepositoryImpl(ref.watch(mapboxSearchDataSourceProvider)),
);

/// Exposed as the domain interface for consumers that only need the
/// contract (per Clean Architecture — features depend on abstractions).
final searchRepositoryContractProvider = Provider<SearchRepository>(
  (ref) => ref.watch(searchRepositoryProvider),
);

final routingRepositoryProvider = Provider<RoutingRepository>(
  (ref) => RoutingRepositoryImpl(ref.watch(mapboxRoutingDataSourceProvider)),
);

final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => ParkingRepositoryImpl(ref.watch(mapboxParkingDataSourceProvider)),
);

final trafficRepositoryProvider = Provider<TrafficRepository>(
  (ref) => const TrafficRepositoryImpl(),
);

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final aiNavigationServiceProvider = Provider<AiNavigationService>(
  (ref) => AiNavigationService(dataSource: ref.watch(groqAiDataSourceProvider)),
);

final locationPermissionHandlerProvider =
    Provider<LocationPermissionHandler>((ref) => const LocationPermissionHandler());

final locationTrackerProvider =
    Provider<LocationTracker>((ref) => const LocationTracker());

final speechToTextServiceProvider =
    Provider<SpeechToTextService>((ref) {
  final service = SpeechToTextService();
  ref.onDispose(service.dispose);
  return service;
});

final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) {
  final service = TextToSpeechService();
  ref.onDispose(service.dispose);
  return service;
});
