import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';

/// Downloads a Mapbox-hosted style JSON and rewrites every `mapbox://`
/// reference inside it (vector/raster sources, `sprite`, `glyphs`) into
/// the equivalent direct HTTPS URL, then caches the result as a local
/// file that `maplibre_gl`'s `styleString` can point at.
///
/// Why this exists: Mapbox's Styles API returns style JSON that uses the
/// `mapbox://` custom scheme internally (e.g.
/// `"url": "mapbox://mapbox.mapbox-streets-v8"`,
/// `"sprite": "mapbox://sprites/mapbox/streets-v12"`,
/// `"glyphs": "mapbox://fonts/mapbox/{fontstack}/{range}.pbf"`).
/// Mapbox's own SDKs resolve that scheme internally, but `maplibre_gl`
/// (MapLibre Native) does not — see
/// https://docs.mapbox.com/help/dive-deeper/mapbox-in-maplibre/ ("MapLibre
/// does not natively resolve mapbox:// scheme URIs"). Without this
/// rewrite, `MapLibreMap` downloads the style successfully (so
/// `onStyleLoadedCallback` still fires) but every source it points to
/// silently fails to resolve, producing a completely blank basemap with
/// no error anywhere — the exact "map loads but shows nothing" symptom
/// this class fixes.
abstract final class MapStyleResolver {
  /// Returns an absolute file path (suitable for `MapLibreMap.styleString`)
  /// pointing at a locally-cached, rewritten copy of the style at
  /// [mapboxStyleUrl] (e.g. `MapStyle.light` / `MapStyle.dark`).
  ///
  /// Caches per style id on disk so repeat calls (e.g. light/dark toggle)
  /// don't re-download every time the app restarts, while still
  /// refreshing whenever the app is reinstalled/updated.
  static Future<String> resolve(String mapboxStyleUrl) async {
    final response = await http
        .get(Uri.parse(mapboxStyleUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException(
        'Mapbox style request failed: HTTP ${response.statusCode}: '
        '${response.body}',
        uri: Uri.parse(mapboxStyleUrl),
      );
    }

    final style = jsonDecode(response.body) as Map<String, dynamic>;
    await _rewriteMapboxUris(style);

    final dir = await getApplicationDocumentsDirectory();
    final styleId = Uri.parse(mapboxStyleUrl).pathSegments.last;
    final file = File('${dir.path}/mapbox_style_$styleId.json');
    await file.writeAsString(jsonEncode(style));
    return file.path;
  }

  /// Resolves a `mapbox://mapbox.<tileset-id>` reference to its direct
  /// HTTPS tile URL template(s) via Mapbox's TileJSON endpoint. Used for
  /// sources added at runtime (e.g. the traffic overlay in
  /// [MapboxMapController.setTrafficVisible]) that aren't part of the
  /// base style JSON rewritten by [resolve].
  static Future<List<String>> resolveTileUrls(String mapboxSourceUrl) async {
    if (!mapboxSourceUrl.startsWith('mapbox://')) {
      return [mapboxSourceUrl];
    }
    final tilesetId = mapboxSourceUrl.substring('mapbox://'.length);
    final tileJsonUri = Uri.parse(
      'https://api.mapbox.com/v4/$tilesetId.json'
      '?secure&access_token=${AppConfig.mapApiKey}',
    );
    final response =
        await http.get(tileJsonUri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException(
        'Mapbox TileJSON request failed for $tilesetId: '
        'HTTP ${response.statusCode}: ${response.body}',
        uri: tileJsonUri,
      );
    }
    final tileJson = jsonDecode(response.body) as Map<String, dynamic>;
    return List<String>.from(tileJson['tiles'] as List);
  }

  static Future<void> _rewriteMapboxUris(Map<String, dynamic> style) async {
    final token = AppConfig.mapApiKey;

    final sprite = style['sprite'];
    if (sprite is String && sprite.startsWith('mapbox://sprites/')) {
      final path = sprite.substring('mapbox://sprites/'.length);
      style['sprite'] =
          'https://api.mapbox.com/styles/v1/$path/sprite?access_token=$token';
    }

    final glyphs = style['glyphs'];
    if (glyphs is String && glyphs.startsWith('mapbox://fonts/')) {
      final path = glyphs.substring('mapbox://fonts/'.length);
      style['glyphs'] =
          'https://api.mapbox.com/fonts/v1/$path?access_token=$token';
    }

    final sources = style['sources'];
    if (sources is! Map<String, dynamic>) return;

    for (final source in sources.values) {
      if (source is! Map<String, dynamic>) continue;
      final url = source['url'];
      if (url is! String || !url.startsWith('mapbox://')) continue;

      // "mapbox://mapbox.mapbox-streets-v8" or a composite tileset id
      // like "mapbox://mapbox.mapbox-streets-v8,mapbox.mapbox-terrain-v2".
      // Resolving via Mapbox's own TileJSON endpoint (rather than
      // hand-building a /v4/ URL template) gets the correct tile format
      // and multi-tileset composite handling for free.
      final tiles = await resolveTileUrls(url);
      source.remove('url');
      source['tiles'] = tiles;
    }
  }
}
