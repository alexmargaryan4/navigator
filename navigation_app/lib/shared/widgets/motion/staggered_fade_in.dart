import 'package:flutter/material.dart';

import '../../../core/animation/animation_curves.dart';

/// Fades + slightly slides a single child in, delayed by [index] *
/// [stagger] — used to give lists of route cards, search results, and
/// parking spots a coordinated "cascade" entrance instead of popping in
/// all at once (see product spec §21, §30).
class StaggeredFadeIn extends StatefulWidget {
  const StaggeredFadeIn({
    super.key,
    required this.child,
    required this.index,
    this.stagger = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 320),
    this.slideOffset = 16,
  });

  final Widget child;
  final int index;
  final Duration stagger;
  final Duration duration;
  final double slideOffset;

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: AppCurves.standard);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 100),
      end: Offset.zero,
    ).animate(_fade);

    final delay = widget.stagger * widget.index;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
