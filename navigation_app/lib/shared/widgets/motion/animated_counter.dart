import 'package:flutter/material.dart';

/// Smoothly tweens a displayed number between updates instead of letting
/// it jump — used for live ETA, remaining distance, and speed readouts
/// during navigation (see product spec §23-24: "avoid visual jumps").
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 450),
    this.curve = Curves.easeOutCubic,
  });

  /// The current target value (e.g. remaining meters, current speed).
  final double value;

  /// Renders the interpolated value at each animation frame — callers
  /// decide formatting (e.g. `'${v.round()} km'`).
  final Widget Function(BuildContext context, double animatedValue) builder;

  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, _) => builder(context, animatedValue),
    );
  }
}

/// Variant driven by an explicit "previous -> next" pair, useful when the
/// caller already tracks the last emitted value (e.g. a
/// [StateNotifier]) and wants a guaranteed tween between exactly those
/// two values rather than relying on widget-rebuild diffing.
class TweenedText extends ImplicitlyAnimatedWidget {
  const TweenedText({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    super.duration = const Duration(milliseconds: 450),
    super.curve = Curves.easeOutCubic,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;

  @override
  ImplicitlyAnimatedWidgetState<TweenedText> createState() => _TweenedTextState();
}

class _TweenedTextState extends AnimatedWidgetBaseState<TweenedText> {
  Tween<double>? _tween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _tween = visitor(
      _tween,
      widget.value,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>;
  }

  @override
  Widget build(BuildContext context) {
    final animatedValue = _tween?.evaluate(animation) ?? widget.value;
    return Text(widget.format(animatedValue), style: widget.style);
  }
}
