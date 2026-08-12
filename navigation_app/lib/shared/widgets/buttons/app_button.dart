import 'package:flutter/material.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../glass/glass_surface.dart';
import 'pressable.dart';

/// Visual weight of an [AppButton].
enum AppButtonVariant {
  /// Full brand-gradient fill — the single strongest call to action on
  /// a screen (e.g. "Start Navigation").
  primary,

  /// Flat, tinted surface with a hairline border in the accent color —
  /// for secondary actions that sit next to a primary button.
  secondary,

  /// Text-only, no fill or border — for the lowest-emphasis actions
  /// (e.g. "Cancel").
  ghost,

  /// Destructive actions (e.g. "End trip").
  danger,
}

enum AppButtonSize { medium, large }

/// The app's single button primitive.
///
/// Replaces ad-hoc [ElevatedButton] usage so every button in the app
/// shares one border radius, one shadow language, and one gradient —
/// the previous design used a plain flat accent fill with a radius that
/// didn't visually agree with its own border, which is what made buttons
/// look slightly "unfinished". This widget fixes that by deriving the
/// border, the shadow, and the content padding from the same radius and
/// size tokens instead of hand-tuning each one per screen.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;

  /// Whether the button fills the available width.
  final bool expand;

  final bool loading;

  bool get _enabled => onTap != null && !loading;

  double get _radius => size == AppButtonSize.large ? 20 : 16;

  double get _height => size == AppButtonSize.large ? 56 : 46;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();

    final content = AnimatedOpacity(
      opacity: _enabled || variant == AppButtonVariant.ghost ? 1 : 0.45,
      duration: motion.microInteraction.duration,
      child: _buildSurface(colors),
    );

    return Pressable(
      onTap: _enabled ? onTap : null,
      enabled: _enabled,
      borderRadius: BorderRadius.circular(_radius),
      scaleAmount: 0.97,
      child: expand ? SizedBox(width: double.infinity, child: content) : content,
    );
  }

  Widget _buildSurface(AppColors colors) {
    final borderRadius = BorderRadius.circular(_radius);
    final textStyle = TextStyle(
      fontSize: size == AppButtonSize.large ? 16 : 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: _foreground(colors),
      height: 1,
    );

    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: size == AppButtonSize.large ? 18 : 16,
            height: size == AppButtonSize.large ? 18 : 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(_foreground(colors)),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: size == AppButtonSize.large ? 20 : 18,
              color: _foreground(colors)),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );

    final padding = EdgeInsets.symmetric(
      horizontal: size == AppButtonSize.large ? 24 : 18,
    );

    switch (variant) {
      case AppButtonVariant.primary:
        return Container(
          height: _height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: AppGradients.brand(colors),
            borderRadius: borderRadius,
            // A 1px highlight border in a lighter tint of the gradient
            // keeps the fill from looking like it's floating without an
            // edge — the previous flat-fill buttons had no border at
            // all, which read as visually "unfinished" against glass
            // surfaces.
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accentShadow,
                blurRadius: 22,
                offset: const Offset(0, 10),
                spreadRadius: -6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: row,
        );

      case AppButtonVariant.secondary:
        return Container(
          height: _height,
          padding: padding,
          decoration: BoxDecoration(
            color: colors.accent.withOpacity(0.10),
            borderRadius: borderRadius,
            border: Border.all(
              color: colors.accent.withOpacity(0.35),
              width: 1.4,
            ),
          ),
          alignment: Alignment.center,
          child: row,
        );

      case AppButtonVariant.ghost:
        return Container(
          height: _height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: colors.divider, width: 1.2),
          ),
          alignment: Alignment.center,
          child: row,
        );

      case AppButtonVariant.danger:
        return Container(
          height: _height,
          padding: padding,
          decoration: BoxDecoration(
            color: colors.error.withOpacity(0.12),
            borderRadius: borderRadius,
            border: Border.all(color: colors.error.withOpacity(0.4), width: 1.4),
          ),
          alignment: Alignment.center,
          child: row,
        );
    }
  }

  Color _foreground(AppColors colors) {
    switch (variant) {
      case AppButtonVariant.primary:
        return colors.onAccent;
      case AppButtonVariant.secondary:
        return colors.accent;
      case AppButtonVariant.ghost:
        return colors.onSurface;
      case AppButtonVariant.danger:
        return colors.error;
    }
  }
}

/// A small circular icon-only button sharing [AppButton]'s border and
/// shadow language — used where a full-width button doesn't fit (close
/// buttons, compact actions inside a card).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;

    // The unfilled variant (e.g. the hamburger menu button in the
    // map's top bar) now renders through GlassSurface itself instead
    // of hand-rolling a similar-looking decoration — that previously
    // drifted out of sync with GlassSurface (no boxShadow, no
    // BackdropFilter) and made it visibly inconsistent with the other
    // circular floating controls (MapActionButton) that already use
    // GlassSurface. Filled stays a plain gradient circle, since that's
    // an "active/on" state, not a neutral surface.
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: filled ? AppGradients.brand(colors) : null,
        border: filled
            ? Border.all(color: Colors.white.withOpacity(0.16), width: 1)
            : null,
      ),
      alignment: Alignment.center,
      child: filled
          ? Icon(icon, size: size * 0.5, color: colors.onAccent)
          : GlassSurface(
              // GlassSurface already clips to this radius internally
              // (ClipRRect), so a circular radius on a square box is
              // enough to produce a perfect circle here.
              borderRadius: BorderRadius.circular(size / 2),
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: size * 0.5,
                  color: colors.onSurfaceMuted,
                ),
              ),
            ),
    );

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      scaleAmount: 0.94,
      child: circle,
    );
  }
}
