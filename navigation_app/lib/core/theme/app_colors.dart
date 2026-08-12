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
    required this.accentSecondary,
    required this.onAccent,
    required this.divider,
    required this.success,
    required this.warning,
    required this.heavy,
    required this.severe,
    required this.error,
    required this.shadow,
    required this.accentShadow,
    required this.inputFill,
    required this.inputBorder,
    required this.inputBorderFocused,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color glassSurface;
  final Color glassBorder;
  final Color onSurface;
  final Color onSurfaceMuted;

  /// Primary brand accent — the deep, calm blue end of the brand gradient.
  final Color accent;

  /// Secondary brand accent — the teal end of the brand gradient. Used
  /// together with [accent] to build [AppGradients.brand] rather than as
  /// a flat color on its own, so the app reads as "one tone" instead of
  /// two competing colors.
  final Color accentSecondary;

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

  /// Soft, tinted shadow used under brand-gradient surfaces (primary
  /// buttons, FAB, splash mark) so elevation reads as "glow", not a
  /// generic gray drop shadow that looks pasted on top of the gradient.
  final Color accentShadow;

  /// Dedicated tokens for text fields / search bars so borders are
  /// deliberate hairlines that match the field's own radius, instead of
  /// inheriting a mismatched default border.
  final Color inputFill;
  final Color inputBorder;
  final Color inputBorderFocused;

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
    Color? accentSecondary,
    Color? onAccent,
    Color? divider,
    Color? success,
    Color? warning,
    Color? heavy,
    Color? severe,
    Color? error,
    Color? shadow,
    Color? accentShadow,
    Color? inputFill,
    Color? inputBorder,
    Color? inputBorderFocused,
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
      accentSecondary: accentSecondary ?? this.accentSecondary,
      onAccent: onAccent ?? this.onAccent,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      heavy: heavy ?? this.heavy,
      severe: severe ?? this.severe,
      error: error ?? this.error,
      shadow: shadow ?? this.shadow,
      accentShadow: accentShadow ?? this.accentShadow,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      inputBorderFocused: inputBorderFocused ?? this.inputBorderFocused,
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
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      heavy: Color.lerp(heavy, other.heavy, t)!,
      severe: Color.lerp(severe, other.severe, t)!,
      error: Color.lerp(error, other.error, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      accentShadow: Color.lerp(accentShadow, other.accentShadow, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputBorderFocused:
          Color.lerp(inputBorderFocused, other.inputBorderFocused, t)!,
    );
  }

  // Brand palette: a restrained blue → teal tone, deliberately desaturated
  // relative to a "loud" ride-hailing yellow so it stays easy on the eyes
  // over long navigation sessions, while still reading as one confident,
  // single-tone brand color rather than two separate accents fighting for
  // attention (see AppGradients.brand for how the two are combined).
  static const light = AppColors(
    background: Color(0xFFF3F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    glassSurface: Color(0xD9FFFFFF),
    glassBorder: Color(0x1F0E7CA8),
    onSurface: Color(0xFF12202B),
    onSurfaceMuted: Color(0xFF5C7080),
    accent: Color(0xFF1768AC),
    accentSecondary: Color(0xFF12B8A6),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0xFFE2E8ED),
    success: Color(0xFF1FAE7A),
    warning: Color(0xFFE0A319),
    heavy: Color(0xFFE07A2E),
    severe: Color(0xFFDD4C4C),
    error: Color(0xFFD64545),
    shadow: Color(0x141B2B3A),
    accentShadow: Color(0x3D1768AC),
    inputFill: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFDCE4E9),
    inputBorderFocused: Color(0xFF1996A6),
  );

  static const dark = AppColors(
    background: Color(0xFF08131A),
    surface: Color(0xFF101E27),
    surfaceElevated: Color(0xFF162836),
    glassSurface: Color(0xB3122430),
    glassBorder: Color(0x2645C2C9),
    onSurface: Color(0xFFEAF2F5),
    onSurfaceMuted: Color(0xFF8CA3B0),
    accent: Color(0xFF3E9BE0),
    accentSecondary: Color(0xFF2FD9C4),
    onAccent: Color(0xFF06141B),
    divider: Color(0xFF203444),
    success: Color(0xFF37C98F),
    warning: Color(0xFFF0BA3E),
    heavy: Color(0xFFF08F4E),
    severe: Color(0xFFEB6767),
    error: Color(0xFFEB6767),
    shadow: Color(0x59000B12),
    accentShadow: Color(0x522FD9C4),
    inputFill: Color(0xFF122530),
    inputBorder: Color(0xFF24404F),
    inputBorderFocused: Color(0xFF2FD9C4),
  );
}

/// Brand gradients built from [AppColors.accent] → [AppColors.accentSecondary].
///
/// Centralized here (rather than inlined at each call site) so every
/// "hero" surface — primary buttons, the FAB, the splash mark — shares
/// the exact same angle and stops and therefore reads as one deliberate
/// tone across the app instead of visually-distinct gradients.
abstract final class AppGradients {
  static LinearGradient brand(AppColors colors) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.accent, colors.accentSecondary],
      );

  static LinearGradient brandSubtle(AppColors colors) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.accent.withOpacity(0.13),
          colors.accentSecondary.withOpacity(0.13),
        ],
      );
}
