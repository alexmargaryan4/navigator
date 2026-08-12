import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/map/presentation/map_screen.dart';
import 'providers/theme_mode_provider.dart';
import 'splash/splash_gate.dart';

/// Root application widget.
///
/// Wires the [ThemeModeNotifier] into [MaterialApp.themeMode] and cross-
/// fades between light/dark palettes using [AnimatedTheme] semantics
/// baked into [AppTheme] (see product spec §53: theme switches must be
/// smooth, never abrupt).
///
/// The app's actual home is wrapped in [SplashGate], which shows the
/// animated [SplashScreen] brand moment first and then cross-fades into
/// [MapScreen] — see splash/splash_gate.dart.
class NavigationApp extends ConsumerWidget {
  const NavigationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Navigator',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const SplashGate(child: MapScreen()),
    );
  }
}
