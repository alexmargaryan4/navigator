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

    // Every input border below shares one radius and one hairline width
    // with its own fill color, so the border always reads as "drawn for
    // this field" instead of a default Material outline that happens to
    // overlap a differently-rounded container.
    final inputRadius = BorderRadius.circular(_radiusMd);

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
          disabledBackgroundColor: colors.accent.withOpacity(0.35),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
            side: BorderSide(color: Colors.white.withOpacity(0.14), width: 1),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSm),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLg),
          side: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colors.inputBorder, width: 1.3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colors.inputBorder, width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colors.inputBorderFocused, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colors.error, width: 1.8),
        ),
        hintStyle: TextStyle(color: colors.onSurfaceMuted),
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
