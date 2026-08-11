/// Supported travel modes, restricted to what the routing provider
/// (Mapbox Directions) actually supports. Public transit, taxi, and
/// similar modes are intentionally out of scope for this app.
enum TravelMode { driving, walking, cycling }

extension TravelModeX on TravelMode {
  /// Mapbox Directions API routing profile identifier.
  String get mapboxProfile => switch (this) {
        TravelMode.driving => 'driving-traffic',
        TravelMode.walking => 'walking',
        TravelMode.cycling => 'cycling',
      };

  String get label => switch (this) {
        TravelMode.driving => 'Driving',
        TravelMode.walking => 'Walking',
        TravelMode.cycling => 'Cycling',
      };
}
