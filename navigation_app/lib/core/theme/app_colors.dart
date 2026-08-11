import 'package:flutter/material.dart';

/// Semantic color tokens, independent of Material's default palette.
///
/// Implemented as a [ThemeExtension] so that switching between light and
/// dark automatically cross-fades every token via [AnimatedTheme] rather
/// than snapping abruptly (see `motion_tokens.dart` -> `themeTransition`).
///
/// Kept deliberately restrained — the map is the visual hero, so UI chrome
/// uses a small, calm palette with a single accent color.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.glassSurface,
    required this.glassBorder,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.accent,
    required this.onAccent,
    required this.divider,
    required this.success,
    required this.warning,
    required this.heavy,
    required this.severe,
    required this.error,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color glassSurface;
  final Color glassBorder;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color accent;
  final Color onAccent;
  final Color divider;

  // Traffic semantic colors (never fabricated — only used to render real
  // traffic-provider data, see lib/services/traffic).
  final Color success; // low traffic
  final Color warning; // moderate
  final Color heavy; // heavy slowdown
  final Color severe; // severe

  final Color error;
  final Color shadow;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? glassSurface,
    Color? glassBorder,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? accent,
    Color? onAccent,
    Color? divider,
    Color? success,
    Color? warning,
    Color? heavy,
    Color? severe,
    Color? error,
    Color? shadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      glassSurface: glassSurface ?? this.glassSurface,
      glassBorder: glassBorder ?? this.glassBorder,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      heavy: heavy ?? this.heavy,
      severe: severe ?? this.severe,
      error: error ?? this.error,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      heavy: Color.lerp(heavy, other.heavy, t)!,
      severe: Color.lerp(severe, other.severe, t)!,
      error: Color.lerp(error, other.error, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }

  static const light = AppColors(
    background: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    glassSurface: Color(0xCCFFFFFF),
    glassBorder: Color(0x33FFFFFF),
    onSurface: Color(0xFF14171F),
    onSurfaceMuted: Color(0xFF6B7280),
    accent: Color(0xFF2563EB),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0xFFE5E7EB),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF5B301),
    heavy: Color(0xFFF97316),
    severe: Color(0xFFEF4444),
    error: Color(0xFFDC2626),
    shadow: Color(0x1A000000),
  );

  static const dark = AppColors(
    background: Color(0xFF0B0D12),
    surface: Color(0xFF14171F),
    surfaceElevated: Color(0xFF1B1F29),
    glassSurface: Color(0x992A2E38),
    glassBorder: Color(0x33FFFFFF),
    onSurface: Color(0xFFF3F4F6),
    onSurfaceMuted: Color(0xFF9AA1AC),
    accent: Color(0xFF4F8DFF),
    onAccent: Color(0xFF0B0D12),
    divider: Color(0xFF262B36),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    heavy: Color(0xFFFB923C),
    severe: Color(0xFFF87171),
    error: Color(0xFFF87171),
    shadow: Color(0x40000000),
  );
}
