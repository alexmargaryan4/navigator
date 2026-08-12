import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The app's brand mark for the splash screen: a navigation-arrow glyph
/// on a brand-gradient disc with a soft ambient glow that gently
/// "breathes" in sync with the splash background's drift.
///
/// Deliberately built as vector shapes (no image asset) so it renders
/// crisply at any size/DPI and can react to [breathe] every frame
/// without needing a sprite sheet.
class SplashMark extends StatelessWidget {
  const SplashMark({super.key, required this.colors, required this.breathe});

  final AppColors colors;

  /// A value oscillating in `[-1, 1]` driving the glow/scale pulse.
  final double breathe;

  @override
  Widget build(BuildContext context) {
    final glowStrength = 0.5 + (breathe * 0.5); // -> [0, 1]

    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient glow — a wide, soft blurred halo behind the disc.
          Container(
            width: 132 + (glowStrength * 14),
            height: 132 + (glowStrength * 14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.accentSecondary.withOpacity(0.35 * glowStrength),
                  colors.accentSecondary.withOpacity(0),
                ],
              ),
            ),
          ),
          // The disc itself.
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand(colors),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accentShadow,
                  blurRadius: 32 + (glowStrength * 10),
                  offset: const Offset(0, 14),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                // A faint, continuous rotation-in-place on the compass
                // needle reads as "orienting" rather than spinning like
                // a loading indicator.
                angle: breathe * 0.06,
                child: CustomPaint(
                  size: const Size(46, 46),
                  painter: _CompassNeedlePainter(color: colors.onAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a simple two-tone compass/navigation needle: a sharp forward
/// point and a shorter tail, echoing the style of `Icons.navigation_rounded`
/// used for re-center/navigation actions elsewhere in the app, so the
/// splash mark and the in-app navigation iconography read as the same
/// visual language.
class _CompassNeedlePainter extends CustomPainter {
  _CompassNeedlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final frontPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final tailPaint = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final frontPath = Path()
      ..moveTo(center.dx, 0)
      ..lineTo(w * 0.78, h * 0.62)
      ..lineTo(center.dx, h * 0.46)
      ..close();

    final tailPath = Path()
      ..moveTo(center.dx, h)
      ..lineTo(w * 0.22, h * 0.62)
      ..lineTo(center.dx, h * 0.46)
      ..close();

    canvas.drawPath(tailPath, tailPaint);
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant _CompassNeedlePainter oldDelegate) =>
      oldDelegate.color != color;
}
