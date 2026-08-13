import 'favorite_route.dart';
import 'travel_mode.dart';

enum TripHistoryStatus {
  /// Navigation was started and reached the destination (or was ended
  /// by the user after making meaningful progress).
  completed,

  /// A route was calculated / navigation was started but ended early.
  started,
}

/// A record of a real trip the user planned or ran (product spec
/// "История маршрутов"). Distance/duration are always the routing
/// provider's own figures for that trip — never recomputed or guessed
/// after the fact.
class TripHistoryEntry {
  const TripHistoryEntry({
    required this.id,
    required this.origin,
    required this.destination,
    this.stops = const [],
    required this.mode,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.date,
    required this.status,
  });

  final String id;
  final FavoriteRouteEndpoint origin;
  final FavoriteRouteEndpoint destination;
  final List<FavoriteRouteEndpoint> stops;
  final TravelMode mode;
  final double distanceMeters;
  final double durationSeconds;
  final DateTime date;
  final TripHistoryStatus status;

  double get distanceKm => distanceMeters / 1000;
  Duration get duration => Duration(seconds: durationSeconds.round());

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'stops': stops.map((s) => s.toJson()).toList(),
        'mode': mode.name,
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'date': date.toIso8601String(),
        'status': status.name,
      };

  factory TripHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TripHistoryEntry(
        id: json['id'] as String,
        origin: FavoriteRouteEndpoint.fromJson(
            json['origin'] as Map<String, dynamic>),
        destination: FavoriteRouteEndpoint.fromJson(
            json['destination'] as Map<String, dynamic>),
        stops: ((json['stops'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(FavoriteRouteEndpoint.fromJson)
            .toList(),
        mode: TravelMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => TravelMode.driving,
        ),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        status: TripHistoryStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => TripHistoryStatus.started,
        ),
      );
}
