import 'package:flutter/material.dart';

import '../../../core/animation/motion_tokens.dart';

/// Wraps any child with premium, consistent press feedback: a subtle
/// scale-down + opacity dip on press, released with a slightly springier
/// curve on lift.
///
/// This is the single building block every tappable surface in the app
/// (buttons, cards, POI markers, list rows) should use instead of
/// hand-rolling its own [GestureDetector] + [AnimatedContainer] pair —
/// see product spec §17 and §33 (centralized motion system).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleAmount = 0.96,
    this.opacityAmount = 0.85,
    this.enabled = true,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How much the child scales down while pressed (1.0 = no change).
  final double scaleAmount;

  /// Opacity applied while pressed (1.0 = no change).
  final double opacityAmount;

  final bool enabled;

  /// Optional clip radius so the press-opacity overlay respects rounded
  /// shapes (cards, chips, pills).
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionTokens.current();
    final spec = motion.buttonPress;

    final content = AnimatedScale(
      scale: _pressed && widget.enabled ? widget.scaleAmount : 1.0,
      duration: spec.duration,
      curve: _pressed ? spec.curve : Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _pressed && widget.enabled ? widget.opacityAmount : 1.0,
        duration: spec.duration,
        curve: spec.curve,
        child: widget.child,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: widget.borderRadius != null
          ? ClipRRect(borderRadius: widget.borderRadius!, child: content)
          : content,
    );
  }
}
