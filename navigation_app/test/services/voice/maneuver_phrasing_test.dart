import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/domain/entities/geo_point.dart';
import 'package:navigation_app/domain/entities/route.dart';
import 'package:navigation_app/services/voice/maneuver_phrasing.dart';

RouteStep _step({
  required String maneuverType,
  String? roadName,
}) {
  return RouteStep(
    instruction: 'raw provider instruction',
    distanceMeters: 250,
    durationSeconds: 40,
    maneuverLocation: const GeoPoint(latitude: 0, longitude: 0),
    maneuverType: maneuverType,
    roadName: roadName,
  );
}

void main() {
  group('ManeuverPhrasing.upcoming', () {
    test('phrases a right turn with a road name', () {
      final phrase = ManeuverPhrasing.upcoming(
        _step(maneuverType: 'turn-right', roadName: 'Main Street'),
        distanceMeters: 300,
      );
      expect(phrase, 'In 300 meters, turn right onto Main Street.');
    });

    test('phrases a left turn without a road name', () {
      final phrase = ManeuverPhrasing.upcoming(
        _step(maneuverType: 'turn-left'),
        distanceMeters: 300,
      );
      expect(phrase, 'In 300 meters, turn left.');
    });

    test('rounds distance to the nearest 50 meters under 1km', () {
      final phrase = ManeuverPhrasing.upcoming(
        _step(maneuverType: 'turn-right', roadName: 'Main Street'),
        distanceMeters: 275,
      );
      expect(phrase, contains('300 meters'));
    });

    test('phrases distances over 1km in kilometers', () {
      final phrase = ManeuverPhrasing.upcoming(
        _step(maneuverType: 'continue', roadName: 'Highway 1'),
        distanceMeters: 2500,
      );
      expect(phrase, contains('2.5 kilometers'));
    });

    test('very short distances say "a moment" rather than "0 meters"', () {
      final phrase = ManeuverPhrasing.upcoming(
        _step(maneuverType: 'turn-right'),
        distanceMeters: 10,
      );
      expect(phrase, contains('a moment'));
    });

    test('roundabout maneuver produces a sensible phrase', () {
      final phrase = ManeuverPhrasing.upcoming(
        _step(maneuverType: 'roundabout'),
        distanceMeters: 100,
      );
      expect(phrase, contains('enter the roundabout'));
    });
  });

  group('ManeuverPhrasing.immediate', () {
    test('capitalizes the first letter of the action phrase', () {
      final phrase = ManeuverPhrasing.immediate(
        _step(maneuverType: 'turn-left', roadName: 'Main Street'),
      );
      expect(phrase, 'Turn left onto Main Street.');
    });

    test('omits "onto <road>" when no road name is available', () {
      final phrase = ManeuverPhrasing.immediate(
        _step(maneuverType: 'turn-right'),
      );
      expect(phrase, 'Turn right.');
    });
  });

  test('arrived is a fixed, unambiguous phrase', () {
    expect(ManeuverPhrasing.arrived, 'You have arrived at your destination.');
  });
}
