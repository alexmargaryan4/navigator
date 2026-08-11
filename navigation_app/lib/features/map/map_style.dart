import '../../core/config/app_config.dart';

/// Centralized Mapbox Style URLs and the vector-source/layer identifiers
/// used to control the traffic overlay on [MapboxMapController].
///
/// The map is rendered with `maplibre_gl` (a MapLibre GL Native binding),
/// pointed at Mapbox-hosted Style JSON — this gives real vector maps and
/// Mapbox's live traffic tiles, without requiring Mapbox's own (non-FOSS)
/// SDK build.
///
/// IMPORTANT: `maplibre_gl` only understands the classic Mapbox Style
/// Spec v8 (`streets-v12`, `light-v11`, `dark-v11`, ...). It does NOT
/// support "Mapbox Standard" (`mapbox/standard`) — that style relies on
/// proprietary 3D/lighting extensions (fog, 3D buildings, the
/// `lightPreset` config option) that only Mapbox's own GL Native SDK
/// implements. Pointing `maplibre_gl` at a Standard style style URL
/// results in a blank map or a map with most of its styling missing.
/// Always use one of the classic styles below.
abstract final class MapStyle {
  static String _styled(String styleId) =>
      'https://api.mapbox.com/styles/v1/mapbox/$styleId'
      '?access_token=${AppConfig.mapApiKey}';

  /// `streets-v12` — Mapbox's most detailed classic style: rich POI
  /// icons, building footprints, road-type coloring and place labels.
  /// Fully supported by MapLibre's vector renderer.
  static String get light => _styled('streets-v12');

  /// `dark-v11` — Mapbox's classic dark-mode style, same level of detail
  /// as `streets-v12` but with a dark basemap. Fully supported by
  /// MapLibre's vector renderer.
  static String get dark => _styled('dark-v11');

  /// Mapbox's live traffic vector tileset, added as an extra source on
  /// top of the base style so the always-on road-coloring traffic
  /// overlay (spec §42) doesn't require a network call of its own — it
  /// rides along with normal vector tile fetches.
  static const String trafficSourceId = 'mapbox-traffic';
  static const String trafficSourceUrl = 'mapbox://mapbox.mapbox-traffic-v1';
  static const String trafficLayerId = 'traffic-flow-layer';

  static const String routeLineSourceId = 'route-line-source';
  static const String routeLineLayerId = 'route-line-layer';
  static const String routeLineCasingLayerId = 'route-line-casing-layer';

  static const String alternativeRouteSourcePrefix = 'alt-route-source-';
  static const String alternativeRouteLayerPrefix = 'alt-route-layer-';

  static const String userLocationSourceId = 'user-location-source';
  static const String userLocationLayerId = 'user-location-layer';

  static const String destinationMarkerSourceId = 'destination-marker-source';
  static const String destinationMarkerLayerId = 'destination-marker-layer';

  static const String parkingMarkersSourceId = 'parking-markers-source';
  static const String parkingMarkersLayerId = 'parking-markers-layer';
}
