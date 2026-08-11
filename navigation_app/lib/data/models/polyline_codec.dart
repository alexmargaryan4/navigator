import '../../domain/entities/geo_point.dart';

/// Decodes Google/Mapbox-style encoded polylines.
///
/// Mapbox Directions responses are requested with `geometries=polyline6`
/// (six decimal-place precision) for accuracy; [precision] must match.
class PolylineCodec {
  static List<GeoPoint> decode(String encoded, {int precision = 6}) {
    final factor = _pow10(precision);
    final points = <GeoPoint>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(GeoPoint(latitude: lat / factor, longitude: lng / factor));
    }

    return points;
  }

  static double _pow10(int n) {
    double r = 1;
    for (int i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}
