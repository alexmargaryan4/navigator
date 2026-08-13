import 'route.dart';

/// The category of an upcoming-event warning surfaced during active
/// navigation (product spec «Умные предупреждения»).
///
/// Every value here is derived exclusively from data the routing
/// provider actually returned for the active route (maneuvers,
/// `congestion` annotations, `maxspeed` annotations) — there is no
/// "road closure" / "roadworks" / "hazard" category because Mapbox's
/// Directions API (the only routing data this app has) doesn't supply
/// that information; per the product requirement to never fabricate a
/// warning from data that isn't actually available, those categories
/// are simply not modeled rather than being backed by invented data.
enum NavWarningType {
  /// A turn/maneuver is coming up — mirrors [RouteStep] but as a
  /// distinct "look ahead" card independent of the primary maneuver
  /// banner, so a complex upcoming step can be flagged earlier.
  upcomingTurn,

  /// The step ahead is a multi-way/roundabout-style maneuver — surfaced
  /// as its own warning because these benefit from extra lead time
  /// (spec «сложный перекрёсток»).
  complexIntersection,

  /// The upcoming step is an off-ramp/exit (spec «предстоящий съезд»).
  upcomingExit,

  /// The real, provider-reported speed limit changes at the upcoming
  /// point on the route (spec «изменение ограничения скорости»).
  speedLimitChange,

  /// A `heavy` or `severe` congestion segment (Mapbox's own
  /// `congestion` annotation) lies ahead on the route (spec «сильная
  /// пробка»).
  heavyTraffic,
}

/// A single proactive, ahead-of-time warning, always built from a real
/// [RouteStep]/[TrafficSegment]/[SpeedLimitSegment] on the currently
/// active route — never synthesized.
class NavWarning {
  const NavWarning({
    required this.type,
    required this.distanceMeters,
    this.roadName,
    this.speedKph,
  });

  final NavWarningType type;

  /// Distance from the user's current position to the event, in
  /// meters — recomputed on every GPS update from real route geometry.
  final double distanceMeters;

  final String? roadName;

  /// Populated only for [NavWarningType.speedLimitChange] — the real
  /// new limit ahead, in km/h.
  final double? speedKph;

  /// A stable identity for de-duplicating "already announced" state
  /// across GPS updates — two warnings of the same type within a few
  /// meters of each other are the same real-world event.
  String get dedupeKey =>
      '${type.name}_${(distanceMeters / 25).round()}_${roadName ?? ''}';
}
