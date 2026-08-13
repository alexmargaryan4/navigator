import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/animation/motion_tokens.dart';
import '../../domain/entities/along_route_poi.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/parking_spot.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/route.dart';
import '../../domain/entities/route_stop.dart';
import 'geojson_builder.dart';
import 'map_style.dart';
import 'map_style_resolver.dart';

/// A thin, app-owned wrapper around [MapLibreMapController].
///
/// This is the single place that knows about `maplibre_gl`'s API surface
/// — every feature widget talks to this controller instead of holding a
/// raw [MapLibreMapController], so the map SDK stays swappable and the
/// UI layer stays declarative about *what* to show rather than *how*.
class MapboxMapController {
  MapboxMapController(this._map);

  final MapLibreMapController _map;
  bool _sourcesReady = false;

  /// Must be called once, right after the style finishes loading
  /// (`MapLibreMap.onStyleLoadedCallback`), before any other method here
  /// is used. Sets up every empty GeoJSON source + layer the app will
  /// ever populate, so later updates are cheap `setGeoJsonSource` calls
  /// rather than repeated add/remove churn.
  Future<void> initializeSources() async {
    if (_sourcesReady) return;

    await _map.addSource(
      MapStyle.routeLineSourceId,
      const GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
    );
    await _map.addLineLayer(
      MapStyle.routeLineSourceId,
      MapStyle.routeLineCasingLayerId,
      const LineLayerProperties(
        lineColor: '#0B1220',
        lineWidth: 11.0,
        lineOpacity: 0.35,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await _map.addLineLayer(
      MapStyle.routeLineSourceId,
      MapStyle.routeLineLayerId,
      const LineLayerProperties(
        lineColor: '#2563EB',
        lineWidth: 8.0,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    await _map.addSource(
      MapStyle.alternativeRouteSourcePrefix + '0',
      const GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
    );
    await _map.addLineLayer(
      MapStyle.alternativeRouteSourcePrefix + '0',
      MapStyle.alternativeRouteLayerPrefix + '0',
      const LineLayerProperties(
        lineColor: '#9AA1AC',
        lineWidth: 6.5,
        lineOpacity: 0.65,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    await _map.addSource(
      MapStyle.destinationMarkerSourceId,
      const GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
    );
    await _map.addCircleLayer(
      MapStyle.destinationMarkerSourceId,
      MapStyle.destinationMarkerLayerId,
      const CircleLayerProperties(
        circleRadius: 8,
        circleColor: '#EF4444',
        circleStrokeWidth: 3,
        circleStrokeColor: '#FFFFFF',
      ),
    );

    await _map.addSource(
      MapStyle.parkingMarkersSourceId,
      const GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
    );
    await _map.addCircleLayer(
      MapStyle.parkingMarkersSourceId,
      MapStyle.parkingMarkersLayerId,
      const CircleLayerProperties(
        circleRadius: 6,
        circleColor: '#2563EB',
        circleStrokeWidth: 2,
        circleStrokeColor: '#FFFFFF',
        circleOpacity: 0.9,
      ),
    );

    // Multi-stop markers (product spec "Маршрут с несколькими
    // остановками": every stop shown as its own marker on the map,
    // numbered in visiting order via the `label` property).
    await _map.addSource(
      MapStyle.stopMarkersSourceId,
      const GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
    );
    await _map.addCircleLayer(
      MapStyle.stopMarkersSourceId,
      MapStyle.stopMarkersLayerId,
      const CircleLayerProperties(
        circleRadius: 9,
        circleColor: '#F5B301',
        circleStrokeWidth: 3,
        circleStrokeColor: '#FFFFFF',
      ),
    );
    await _map.addSymbolLayer(
      MapStyle.stopMarkersSourceId,
      MapStyle.stopMarkersLabelLayerId,
      const SymbolLayerProperties(
        textField: '{label}',
        textSize: 11,
        textColor: '#0B1220',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
    );

    // «По пути» POI markers found along the active route (product spec
    // «По пути») — a distinct visual style from search/parking markers
    // so it reads as "found on your way", not a generic result.
    await _map.addSource(
      MapStyle.alongRoutePoiSourceId,
      const GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
    );
    await _map.addCircleLayer(
      MapStyle.alongRoutePoiSourceId,
      MapStyle.alongRoutePoiLayerId,
      const CircleLayerProperties(
        circleRadius: 7,
        circleColor: '#12B8A6',
        circleStrokeWidth: 2,
        circleStrokeColor: '#FFFFFF',
        circleOpacity: 0.95,
      ),
    );

    await _addBuildingExtrusionLayer();

    _sourcesReady = true;
  }

  /// Adds a 3D-building `fill-extrusion` layer on top of the classic
  /// Mapbox `streets`/`dark` style's own `building` layer (product spec
  /// "3D-здания, если они доступны").
  ///
  /// The classic Mapbox Style Spec styles this app uses (see the note
  /// on [MapStyle] about why `mapbox/standard` can't be used with
  /// MapLibre Native) already ship a vector `building` layer with real
  /// `height`/`min_height` feature properties — they just render it
  /// flat by default. Adding our own `fill-extrusion` layer reading
  /// those same properties turns it into real massed 3D buildings
  /// without needing Mapbox's proprietary Standard style. If a style
  /// ever doesn't carry that layer/properties (e.g. a future non-Mapbox
  /// style), this fails silently and the map simply stays 2D — never a
  /// crash, and never fabricated building heights.
  Future<void> _addBuildingExtrusionLayer() async {
    try {
      await _map.addFillExtrusionLayer(
        'composite',
        MapStyle.buildingExtrusionLayerId,
        FillExtrusionLayerProperties(
          fillExtrusionColor: '#B8C4CC',
          fillExtrusionOpacity: 0.75,
          fillExtrusionHeight: [
            Expressions.get,
            'height',
          ],
          fillExtrusionBase: [
            Expressions.get,
            'min_height',
          ],
        ),
        sourceLayer: 'building',
        minzoom: 15,
        filter: [
          Expressions.eq,
          [Expressions.get, 'extrude'],
          'true',
        ],
      );
    } catch (_) {
      // Style doesn't expose a 'building' source-layer with the
      // expected properties — degrade gracefully to the flat 2D
      // building footprints the base style already draws.
    }
  }

  // ---------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------

  /// Short, local camera move (e.g. re-centering on the user). Uses
  /// [MotionTokens.mapCameraShort] so every "snap back to me" feels the
  /// same duration app-wide.
  Future<void> animateToLocation(
    GeoPoint point, {
    double zoom = 16,
    double? bearing,
    double? tilt,
  }) {
    final spec = MotionTokens.current().mapCameraShort;
    return _map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(point.latitude, point.longitude),
          zoom: zoom,
          bearing: bearing ?? 0,
          tilt: tilt ?? 0,
        ),
      ),
      duration: spec.duration,
    );
  }

  /// Long camera jump (e.g. a newly selected search result far from the
  /// current viewport). Uses [MotionTokens.mapCameraLong] for a more
  /// deliberate, cinematic feel.
  Future<void> flyToLocation(GeoPoint point, {double zoom = 15}) {
    final spec = MotionTokens.current().mapCameraLong;
    return _map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(point.latitude, point.longitude), zoom: zoom),
      ),
      duration: spec.duration,
    );
  }

  /// Fits the camera to a route's full extent, used right after a route
  /// is calculated so the whole path (plus a little breathing room) is
  /// visible before the "draw on" animation plays.
  Future<void> fitToRoute(NavRoute route, {EdgeInsets padding = const EdgeInsets.all(64)}) {
    if (route.geometry.isEmpty) return Future.value();

    var minLat = route.geometry.first.latitude;
    var maxLat = route.geometry.first.latitude;
    var minLng = route.geometry.first.longitude;
    var maxLng = route.geometry.first.longitude;

    for (final p in route.geometry) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final spec = MotionTokens.current().mapCameraLong;
    return _map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: padding.left,
        right: padding.right,
        top: padding.top,
        bottom: padding.bottom,
      ),
      duration: spec.duration,
    );
  }

  /// Rotates + tilts into "follow" navigation framing (spec §22-24):
  /// closer zoom, a forward tilt, and bearing aligned with the user's
  /// heading so the map itself appears to rotate as they turn.
  Future<void> enterNavigationCamera(GeoPoint point, {required double bearing}) {
    final spec = MotionTokens.current().navigationTransition;
    return _map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(point.latitude, point.longitude),
          zoom: 18,
          tilt: 55,
          bearing: bearing,
        ),
      ),
      duration: spec.duration,
    );
  }

  /// Frame-to-frame follow update during active navigation — short
  /// duration so it keeps pace with frequent GPS samples without ever
  /// feeling like it's "catching up".
  ///
  /// [maneuverProximity] is `0.0` when no maneuver is close (the
  /// standard navigation zoom/tilt applies) ramping up to `1.0` right
  /// at the maneuver, smoothly pushing zoom up to [_maxManeuverZoom]
  /// and tilt down slightly so the upcoming turn reads clearly (product
  /// spec «плавное приближение перед поворотами») — never a hard cut,
  /// since every value here is a continuous interpolation of the same
  /// two endpoints frame to frame.
  Future<void> followUser(
    GeoPoint point, {
    required double bearing,
    double maneuverProximity = 0.0,
  }) {
    final t = maneuverProximity.clamp(0.0, 1.0);
    final zoom = _lerp(_baseNavigationZoom, _maxManeuverZoom, t);
    final tilt = _lerp(_baseNavigationTilt, _maneuverTilt, t);

    final spec = MotionTokens.current().locationMarkerMove;
    return _map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(point.latitude, point.longitude),
          zoom: zoom,
          tilt: tilt,
          bearing: bearing,
        ),
      ),
      duration: spec.duration,
    );
  }

  static const double _baseNavigationZoom = 18;
  static const double _maxManeuverZoom = 19.4;
  static const double _baseNavigationTilt = 55;
  static const double _maneuverTilt = 50;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  Future<void> zoomToWorldView() {
    final spec = MotionTokens.current().mapCameraLong;
    return _map.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: LatLng(20, 0), zoom: 1.2, tilt: 0, bearing: 0),
      ),
      duration: spec.duration,
    );
  }

  // ---------------------------------------------------------------------
  // Route / marker rendering
  // ---------------------------------------------------------------------

  Future<void> showRoutes(List<NavRoute> routes) async {
    final primary = routes.where((r) => r.isPrimary).toList();
    if (primary.isNotEmpty) {
      await _map.setGeoJsonSource(
        MapStyle.routeLineSourceId,
        GeoJsonBuilder.routeLine(primary.first),
      );
    }
    await _map.setGeoJsonSource(
      MapStyle.alternativeRouteSourcePrefix + '0',
      GeoJsonBuilder.alternativeRoutes(routes),
    );
  }

  Future<void> clearRoutes() async {
    await _map.setGeoJsonSource(
      MapStyle.routeLineSourceId,
      const {'type': 'FeatureCollection', 'features': []},
    );
    await _map.setGeoJsonSource(
      MapStyle.alternativeRouteSourcePrefix + '0',
      const {'type': 'FeatureCollection', 'features': []},
    );
  }

  Future<void> showDestinationMarker(GeoPoint point) => _map.setGeoJsonSource(
        MapStyle.destinationMarkerSourceId,
        GeoJsonBuilder.singleMarker(point),
      );

  Future<void> clearDestinationMarker() => _map.setGeoJsonSource(
        MapStyle.destinationMarkerSourceId,
        const {'type': 'FeatureCollection', 'features': []},
      );

  Future<void> showParkingSpots(List<ParkingSpot> spots) => _map.setGeoJsonSource(
        MapStyle.parkingMarkersSourceId,
        GeoJsonBuilder.parkingMarkers(spots),
      );

  Future<void> clearParkingSpots() => _map.setGeoJsonSource(
        MapStyle.parkingMarkersSourceId,
        const {'type': 'FeatureCollection', 'features': []},
      );

  Future<void> showSearchResults(List<Place> places) => _map.setGeoJsonSource(
        MapStyle.parkingMarkersSourceId,
        GeoJsonBuilder.placeMarkers(places),
      );

  // ---------------------------------------------------------------------
  // Traffic + style
  // ---------------------------------------------------------------------

  bool _trafficVisible = false;
  bool get isTrafficVisible => _trafficVisible;

  /// Toggles Mapbox's live traffic vector-tile layer directly on the
  /// base map (spec §42) — independent of any calculated route.
  ///
  /// Uses direct HTTPS tile URLs (via [MapStyleResolver.resolveTileUrls])
  /// rather than the raw `mapbox://` source URL, since maplibre_gl
  /// (MapLibre Native) doesn't resolve that scheme — see the note on
  /// [MapStyleResolver] for the full explanation.
  Future<void> setTrafficVisible(bool visible) async {
    _trafficVisible = visible;
    try {
      if (visible) {
        final tileUrls =
            await MapStyleResolver.resolveTileUrls(MapStyle.trafficSourceUrl);
        await _map.addSource(
          MapStyle.trafficSourceId,
          VectorSourceProperties(tiles: tileUrls),
        );
        await _map.addLineLayer(
          MapStyle.trafficSourceId,
          MapStyle.trafficLayerId,
          const LineLayerProperties(
            lineWidth: 4.0,
            lineColor: [
              Expressions.match,
              [Expressions.get, 'congestion'],
              'low',
              '#22C55E',
              'moderate',
              '#F5B301',
              'heavy',
              '#F97316',
              'severe',
              '#EF4444',
              '#9AA1AC',
            ],
          ),
          sourceLayer: 'traffic',
        );
      } else {
        await _map.removeLayer(MapStyle.trafficLayerId);
        await _map.removeSource(MapStyle.trafficSourceId);
      }
    } catch (_) {
      // Layer/source already in the desired state (e.g. toggled twice
      // quickly) — safe to ignore, the visible flag above is still
      // correct for the UI toggle.
    }
  }

  Future<void> setMyLocationEnabled(bool enabled) =>
      _map.updateMyLocationTrackingMode(
        enabled ? MyLocationTrackingMode.tracking : MyLocationTrackingMode.none,
      );
}
