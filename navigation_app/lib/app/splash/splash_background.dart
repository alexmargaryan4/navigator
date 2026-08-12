import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Paints a base gradient plus several slowly-drifting, softly-blurred
/// radial color fields ("blobs") in the app's brand blue/teal range.
///
/// This is what turns the splash from "a flat colored screen" into
/// something that feels alive and premium — every color sampled here is
/// derived from [AppColors.accent]/[AppColors.accentSecondary], so no
/// matter how the blobs move, the screen always reads as one coherent
/// tone rather than a random assortment of colors.
class SplashBackgroundPainter extends CustomPainter {
  SplashBackgroundPainter({
    required this.t,
    required this.colors,
    required this.brightness,
  });

  /// Animation progress in `[0, 1)`, looping.
  final double t;
  final AppColors colors;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base vertical wash from background to a barely-there tint of the
    // accent, anchoring every blob drawn on top to the same tone.
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.background,
          Color.lerp(colors.background, colors.accent, 0.10)!,
          Color.lerp(colors.background, colors.accentSecondary, 0.14)!,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final blurredLayer = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70);
    canvas.saveLayer(rect, blurredLayer);

    final blobs = _blobSpecs(size);
    for (final blob in blobs) {
      final angle = (t * 2 * math.pi * blob.speed) + blob.phase;
      final dx = math.cos(angle) * blob.orbitRadius;
      final dy = math.sin(angle * blob.verticalFactor) * blob.orbitRadius * 0.6;
      final center = blob.origin + Offset(dx, dy);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color.withOpacity(blob.opacity),
            blob.color.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: blob.radius));

      canvas.drawCircle(center, blob.radius, paint);
    }

    canvas.restore();

    // A subtle vignette keeps the edges calm so the center — where the
    // brand mark sits — stays the visual focus.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          colors.background.withOpacity(brightness == Brightness.dark ? 0.55 : 0.35),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  List<_BlobSpec> _blobSpecs(Size size) {
    final w = size.width;
    final h = size.height;
    final isDark = brightness == Brightness.dark;
    final opacityScale = isDark ? 1.0 : 0.7;

    return [
      _BlobSpec(
        origin: Offset(w * 0.22, h * 0.28),
        color: colors.accent,
        radius: w * 0.55,
        orbitRadius: w * 0.10,
        speed: 1.0,
        phase: 0,
        verticalFactor: 1.3,
        opacity: 0.30 * opacityScale,
      ),
      _BlobSpec(
        origin: Offset(w * 0.82, h * 0.22),
        color: colors.accentSecondary,
        radius: w * 0.5,
        orbitRadius: w * 0.08,
        speed: 0.8,
        phase: math.pi * 0.6,
        verticalFactor: 0.9,
        opacity: 0.26 * opacityScale,
      ),
      _BlobSpec(
        origin: Offset(w * 0.5, h * 0.85),
        color: colors.accentSecondary,
        radius: w * 0.6,
        orbitRadius: w * 0.12,
        speed: 0.6,
        phase: math.pi * 1.2,
        verticalFactor: 1.1,
        opacity: 0.24 * opacityScale,
      ),
      _BlobSpec(
        origin: Offset(w * 0.15, h * 0.78),
        color: colors.accent,
        radius: w * 0.42,
        orbitRadius: w * 0.09,
        speed: 1.2,
        phase: math.pi * 1.7,
        verticalFactor: 1.0,
        opacity: 0.20 * opacityScale,
      ),
    ];
  }

  @override
  bool shouldRepaint(covariant SplashBackgroundPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.colors != colors ||
      oldDelegate.brightness != brightness;
}

class _BlobSpec {
  const _BlobSpec({
    required this.origin,
    required this.color,
    required this.radius,
    required this.orbitRadius,
    required this.speed,
    required this.phase,
    required this.verticalFactor,
    required this.opacity,
  });

  final Offset origin;
  final Color color;
  final double radius;
  final double orbitRadius;
  final double speed;
  final double phase;
  final double verticalFactor;
  final double opacity;
}
