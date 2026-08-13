import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/features/navigation/application/trip_state.dart';

void main() {
  group('TripState.isSpeeding', () {
    test('false when neither speed nor limit is known', () {
      const state = TripState();
      expect(state.isSpeeding, isFalse);
    });

    test('false when only current speed is known (no real limit to compare)', () {
      final state = TripState.idleState.copyWith(currentSpeedKph: 80);
      expect(state.isSpeeding, isFalse);
    });

    test('false when only the limit is known (no real current speed)', () {
      final state = TripState.idleState.copyWith(currentSpeedLimitKph: 60);
      expect(state.isSpeeding, isFalse);
    });

    test('false within tolerance just above the limit', () {
      final state = TripState.idleState.copyWith(
        currentSpeedKph: 63,
        currentSpeedLimitKph: 60,
      );
      expect(state.isSpeeding, isFalse);
    });

    test('true once clearly over the real limit', () {
      final state = TripState.idleState.copyWith(
        currentSpeedKph: 80,
        currentSpeedLimitKph: 60,
      );
      expect(state.isSpeeding, isTrue);
    });

    test('false at or under the real limit', () {
      final state = TripState.idleState.copyWith(
        currentSpeedKph: 58,
        currentSpeedLimitKph: 60,
      );
      expect(state.isSpeeding, isFalse);
    });

    test('clearCurrentSpeedKph resets the field to null', () {
      final withSpeed = TripState.idleState.copyWith(currentSpeedKph: 80);
      final cleared = withSpeed.copyWith(clearCurrentSpeedKph: true);
      expect(cleared.currentSpeedKph, isNull);
    });

    test('clearCurrentSpeedLimitKph resets the field to null', () {
      final withLimit = TripState.idleState.copyWith(currentSpeedLimitKph: 60);
      final cleared = withLimit.copyWith(clearCurrentSpeedLimitKph: true);
      expect(cleared.currentSpeedLimitKph, isNull);
    });
  });
}
