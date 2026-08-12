import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';

/// The app's flat floating-surface treatment: a solid tinted panel with
/// a hairline neutral border, matching [AppIconButton]'s look (the
/// "hamburger menu" button) so every floating surface in the app —
/// buttons, the search bar, and bottom-sheet cards alike — reads as one
/// consistent, plain style.
///
/// Previously this was a blurred "Liquid Glass" panel (a `BackdropFilter`
/// blur + a semi-transparent tinted fill + a colored hairline border).
/// That look was visually distinct from every button in the app, which
/// all use a flat opaque-ish fill with a neutral divider-colored border
/// and no blur — so surfaces like the "Where to?" search bar and the
/// map's circular action buttons looked like a different design system
/// from the rest of the UI. This version intentionally drops the blur
/// and switches to the same neutral fill/border pairing [AppIconButton]
/// uses, so there's a single flat style everywhere.
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

  /// Kept for backwards compatibility with existing call sites; no
  /// longer used now that this surface is flat rather than blurred.
  final double blurSigma;
  final EdgeInsetsGeometry? padding;

  /// When false, animates the surface away (used e.g. when a panel is
  /// dismissed but still present during its exit animation).
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();
    final spec = motion.overlayFade;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 2,
          sigmaY: 2,
        ),
        child: AnimatedContainer(
          duration: spec.duration,
          curve: spec.curve,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: visible
                ? colors.onSurface.withOpacity(0.06)
                : colors.onSurface.withOpacity(0),
            border: Border.all(
              color: colors.divider,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: spec.duration,
            curve: spec.curve,
            child: child,
          ),
        ),
      ),
    );
  }
}
