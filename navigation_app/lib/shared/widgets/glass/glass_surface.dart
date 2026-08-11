import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_colors.dart';

/// A restrained "Liquid Glass" surface: a blurred, semi-transparent panel
/// with a soft border and shadow that animates in/out smoothly.
///
/// Deliberately subtle per product spec §26 ("premium, not flashy") — the
/// blur sigma and opacity are kept low so text stays crisp and the map
/// underneath remains legible.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 18,
    this.padding,
    this.visible = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;

  /// When false, animates the glass effect away (used e.g. when a panel
  /// is dismissed but still present during its exit animation).
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();
    final spec = motion.overlayFade;

    return ClipRRect(
      borderRadius: borderRadius,
      child: AnimatedContainer(
        duration: spec.duration,
        curve: spec.curve,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: colors.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: visible ? blurSigma : 0,
            sigmaY: visible ? blurSigma : 0,
          ),
          child: AnimatedContainer(
            duration: spec.duration,
            curve: spec.curve,
            padding: padding ?? const EdgeInsets.all(16),
            color: visible
                ? colors.glassSurface
                : colors.glassSurface.withOpacity(0),
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: spec.duration,
              curve: spec.curve,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
