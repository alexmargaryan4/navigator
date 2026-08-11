import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

export 'app_colors.dart';

/// Builds Flutter [ThemeData] from our semantic [AppColors] tokens.
///
/// Rounded, comfortable shapes and restrained elevation are used
/// throughout, per the product's "premium, not flashy" visual direction.
class AppTheme {
  AppTheme._();

  static const double _radiusSm = 12;
  static const double _radiusMd = 18;
  static const double _radiusLg = 28;

  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final colorScheme = brightness == Brightness.light
        ? ColorScheme.light(
            primary: colors.accent,
            onPrimary: colors.onAccent,
            surface: colors.surface,
            onSurface: colors.onSurface,
            error: colors.error,
          )
        : ColorScheme.dark(
            primary: colors.accent,
            onPrimary: colors.onAccent,
            surface: colors.surface,
            onSurface: colors.onSurface,
            error: colors.error,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      textTheme: GoogleFonts.interTextTheme(_textTheme(colors)),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: [colors],
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusLg),
          borderSide: BorderSide.none,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusLg)),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static TextTheme _textTheme(AppColors colors) {
    final base = ThemeData.light().textTheme;
    return base.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );
  }

  static double radiusSm() => _radiusSm;
  static double radiusMd() => _radiusMd;
  static double radiusLg() => _radiusLg;
}

/// Makes [AppColors] retrievable via `Theme.of(context).extension<AppColors>()`.
extension AppColorsX on ThemeData {
  AppColors get appColors => extension<AppColors>() ?? AppColors.light;
}
