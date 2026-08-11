import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/data/models/polyline_codec.dart';
import 'package:navigation_app/domain/entities/geo_point.dart';

void main() {
  group('PolylineCodec.decode', () {
    test('decodes an empty string to an empty list', () {
      expect(PolylineCodec.decode(''), isEmpty);
    });

    test('decodes a known precision-6 encoded polyline to the exact points',
        () {
      // Fixture generated independently from the known source points
      // [(40.1772, 44.5035), (40.18, 44.51), (40.175, 44.52)] using the
      // standard encoded-polyline algorithm at 6 decimal places of
      // precision, matching Mapbox's `geometries=polyline6` (see
      // PolylineCodec doc comment).
      const encoded = '_bfskAw{g{sA_nDguKnwH_pR';

      final decoded = PolylineCodec.decode(encoded, precision: 6);

      expect(decoded, hasLength(3));
      _expectCloseTo(decoded[0], const GeoPoint(latitude: 40.1772, longitude: 44.5035));
      _expectCloseTo(decoded[1], const GeoPoint(latitude: 40.18, longitude: 44.51));
      _expectCloseTo(decoded[2], const GeoPoint(latitude: 40.175, longitude: 44.52));
    });

    test('a single-point polyline round-trips to one GeoPoint', () {
      // Single point at (38.0, -122.0) with precision 5, the classic
      // Google Encoded Polyline Algorithm Format documentation example
      // prefix ("_p~iF~ps|U" encodes (38.5, -120.2) at precision 5).
      const encoded = '_p~iF~ps|U';
      final decoded = PolylineCodec.decode(encoded, precision: 5);
      expect(decoded, hasLength(1));
      _expectCloseTo(
        decoded.first,
        const GeoPoint(latitude: 38.5, longitude: -120.2),
        tolerance: 1e-4,
      );
    });
  });
}

void _expectCloseTo(GeoPoint actual, GeoPoint expected, {double tolerance = 1e-5}) {
  expect(actual.latitude, closeTo(expected.latitude, tolerance));
  expect(actual.longitude, closeTo(expected.longitude, tolerance));
}
