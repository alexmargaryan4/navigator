import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Entry point.
///
/// Kept intentionally thin — all real setup (providers, theme, DI) lives
/// under `lib/app/`. `WidgetsFlutterBinding.ensureInitialized()` is
/// required before any platform-channel call (geolocator, permission
/// handler, speech/tts) can safely run.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NavigationApp()));
}
