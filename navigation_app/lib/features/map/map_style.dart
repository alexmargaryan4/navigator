import '../../core/config/app_config.dart';

/// The user-facing map rendering mode (product spec: map-mode switcher in
/// Settings). Independent of light/dark *theme* — [satellite] has its own
/// single look and doesn't follow the app's brightness, while [standard]
/// still swaps between [MapStyle.light] and [MapStyle.dark] as it always
/// has.
enum MapType {
  /// The existing vector street map, following the app's light/dark theme.
  standard,

  /// Satellite imagery with street/label overlays ([MapStyle.satellite]).
  satellite;

  static const MapType fallback = MapType.standard;
}

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

  /// `satellite-streets-v12` — Mapbox's satellite imagery basemap with
  /// vector street/label/road overlays on top (roads, place names,
  /// POIs), so it stays fully navigable rather than being bare aerial
  /// photography. Same classic Style Spec v8 family as [light]/[dark],
  /// so it's fully supported by MapLibre's renderer — no Mapbox Standard
  /// / GL Native dependency involved.
  static String get satellite => _styled('satellite-streets-v12');

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

  /// Multi-stop route markers (product spec "Маршрут с несколькими
  /// остановками"): one circle per stop plus a numbered label on top.
  static const String stopMarkersSourceId = 'stop-markers-source';
  static const String stopMarkersLayerId = 'stop-markers-layer';
  static const String stopMarkersLabelLayerId = 'stop-markers-label-layer';

  /// "По пути" POI markers found along the active route (product spec
  /// «По пути»).
  static const String alongRoutePoiSourceId = 'along-route-poi-source';
  static const String alongRoutePoiLayerId = 'along-route-poi-layer';

  /// 3D building `fill-extrusion` layer id (product spec "3D-здания,
  /// если они доступны"). Reads the classic style's own `building`
  /// source-layer — see [_addBuildingExtrusionLayer] in
  /// [MapboxMapController].
  static const String buildingExtrusionLayerId = 'building-extrusion-layer';
}
