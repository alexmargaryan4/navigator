import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/domain/entities/nav_warning.dart';

void main() {
  group('NavWarning.dedupeKey', () {
    test('two samples of the same event a few meters apart share a key', () {
      const a = NavWarning(
        type: NavWarningType.heavyTraffic,
        distanceMeters: 802,
      );
      const b = NavWarning(
        type: NavWarningType.heavyTraffic,
        distanceMeters: 788,
      );
      expect(a.dedupeKey, equals(b.dedupeKey));
    });

    test('different warning types never share a key', () {
      const traffic = NavWarning(
        type: NavWarningType.heavyTraffic,
        distanceMeters: 500,
      );
      const turn = NavWarning(
        type: NavWarningType.upcomingTurn,
        distanceMeters: 500,
      );
      expect(traffic.dedupeKey, isNot(equals(turn.dedupeKey)));
    });

    test('the same road name at very different distances differs', () {
      const near = NavWarning(
        type: NavWarningType.upcomingTurn,
        distanceMeters: 50,
        roadName: 'Main Street',
      );
      const far = NavWarning(
        type: NavWarningType.upcomingTurn,
        distanceMeters: 400,
        roadName: 'Main Street',
      );
      expect(near.dedupeKey, isNot(equals(far.dedupeKey)));
    });

    test('a speed limit change carries its real new limit, not a guess', () {
      const warning = NavWarning(
        type: NavWarningType.speedLimitChange,
        distanceMeters: 120,
        speedKph: 90,
      );
      expect(warning.speedKph, 90);
    });
  });
}
