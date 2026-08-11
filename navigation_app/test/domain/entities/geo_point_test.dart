import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/domain/entities/geo_point.dart';

void main() {
  group('GeoPoint', () {
    test('two points with identical coordinates are equal', () {
      const a = GeoPoint(latitude: 40.1772, longitude: 44.5035);
      const b = GeoPoint(latitude: 40.1772, longitude: 44.5035);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('points with different coordinates are not equal', () {
      const a = GeoPoint(latitude: 40.1772, longitude: 44.5035);
      const b = GeoPoint(latitude: 40.1500, longitude: 44.5000);
      expect(a, isNot(equals(b)));
    });

    test('toString includes both coordinates', () {
      const point = GeoPoint(latitude: 1.5, longitude: -2.5);
      expect(point.toString(), contains('1.5'));
      expect(point.toString(), contains('-2.5'));
    });
  });
}
