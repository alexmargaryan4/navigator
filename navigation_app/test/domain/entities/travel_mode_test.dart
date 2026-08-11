import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/domain/entities/travel_mode.dart';

void main() {
  group('TravelModeX', () {
    test('driving maps to the traffic-aware Mapbox profile', () {
      expect(TravelMode.driving.mapboxProfile, 'driving-traffic');
    });

    test('walking maps to the walking Mapbox profile', () {
      expect(TravelMode.walking.mapboxProfile, 'walking');
    });

    test('cycling maps to the cycling Mapbox profile', () {
      expect(TravelMode.cycling.mapboxProfile, 'cycling');
    });

    test('every mode has a non-empty, human-readable label', () {
      for (final mode in TravelMode.values) {
        expect(mode.label, isNotEmpty);
      }
    });

    test('only driving, walking and cycling are supported (spec §12/§40)',
        () {
      // Locks the enum to the in-scope modes so a future edit adding
      // e.g. "transit" or "taxi" fails this test rather than silently
      // expanding scope.
      expect(
        TravelMode.values,
        containsAll(<TravelMode>[
          TravelMode.driving,
          TravelMode.walking,
          TravelMode.cycling,
        ]),
      );
      expect(TravelMode.values.length, 3);
    });
  });
}
