import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/animation/motion_tokens.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/parking_spot.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/route.dart';
import 'geojson_builder.dart';
import 'map_style.dart';

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
        lineWidth: [Expressions.interpolate, 'linear', Expressions.zoom, 10, 8, 18, 16],
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
        lineWidth: [Expressions.interpolate, 'linear', Expressions.zoom, 10, 5, 18, 12],
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
        lineWidth: [Expressions.interpolate, 'linear', Expressions.zoom, 10, 4, 18, 9],
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

    _sourcesReady = true;
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
  Future<void> followUser(GeoPoint point, {required double bearing}) {
    final spec = MotionTokens.current().locationMarkerMove;
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
  Future<void> setTrafficVisible(bool visible) async {
    _trafficVisible = visible;
    try {
      if (visible) {
        await _map.addSource(
          MapStyle.trafficSourceId,
          const VectorSourceProperties(url: MapStyle.trafficSourceUrl),
        );
        await _map.addLineLayer(
          MapStyle.trafficSourceId,
          MapStyle.trafficLayerId,
          const LineLayerProperties(
            lineWidth: [Expressions.interpolate, 'linear', Expressions.zoom, 10, 2, 18, 6],
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

  /// Switches Mapbox Standard's `lightPreset` config (day/night) instead
  /// of swapping the whole style URL, so light/dark theme changes never
  /// trigger a full style reload / visible flash (see [MapStyle]).
  ///
  /// NOTE: `maplibre_gl`'s [MapLibreMapController] doesn't expose a style
  /// import-config API (that's a Mapbox GL Native-only concept), so this
  /// currently falls straight through to the safe no-op below. If we
  /// migrate to a Mapbox Standard-capable renderer later, swap this back
  /// to a real `setStyleImportConfigProperty('basemap', 'lightPreset',
  /// preset)` call.
  Future<void> setLightPreset(String preset) async {
    try {
      // Unsupported by maplibre_gl today — see NOTE above.
    } catch (_) {
      // Older/alternate styles may not expose a "basemap" import or a
      // lightPreset config — safe to ignore, the base style's own
      // default brightness still applies.
    }
  }
}
