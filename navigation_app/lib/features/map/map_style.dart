import '../../core/config/app_config.dart';

/// Centralized Mapbox Style URLs and the vector-source/layer identifiers
/// used to control the traffic overlay on [MapboxMapController].
///
/// The map is rendered with `maplibre_gl` (a MapLibre GL Native binding)
/// pointed at Mapbox-hosted Style JSON — this gives real vector maps,
/// light/dark styles, and Mapbox's live traffic tiles, without requiring
/// Mapbox's own (non-FOSS) SDK build.
abstract final class MapStyle {
  static String _styled(String styleId) =>
      'https://api.mapbox.com/styles/v1/mapbox/$styleId'
      '?access_token=${AppConfig.mapApiKey}';

  static String get light => _styled('standard');
  static String get dark => _styled('standard');

  /// Mapbox Standard supports a `lightPreset` config option instead of
  /// separate style URLs (dawn/day/dusk/night) — light/dark map
  /// switching in this app is therefore driven by
  /// [MapboxMapController.setLightPreset] rather than swapping style
  /// URLs, which would otherwise cause a jarring full style reload.
  static const String lightPresetDay = 'day';
  static const String lightPresetNight = 'night';

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
