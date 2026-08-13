import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/map/map_style.dart';

/// Holds the user's selected [MapType] (standard vector map / satellite).
///
/// Mirrors [ThemeModeNotifier]: kept intentionally simple (in-memory)
/// here — persistence is wired through [lib/features/settings] via
/// shared_preferences without leaking that dependency into this
/// provider's public API.
class MapTypeNotifier extends Notifier<MapType> {
  @override
  MapType build() => MapType.fallback;

  void setType(MapType type) => state = type;
}

final mapTypeProvider =
    NotifierProvider<MapTypeNotifier, MapType>(MapTypeNotifier.new);
