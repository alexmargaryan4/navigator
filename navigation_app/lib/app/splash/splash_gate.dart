import 'package:flutter/material.dart';

import '../../core/animation/animation_curves.dart';
import 'splash_screen.dart';

/// Hosts [SplashScreen] for a minimum duration, then cross-fades into
/// [child] with a coordinated fade + gentle scale — never an abrupt cut
/// from splash to map, and never so long that the splash overstays a
/// fast cold start.
///
/// The minimum duration is intentionally generous enough for the
/// entrance animation in [SplashScreen] to fully play out at least once
/// even on a fast device, so the splash always reads as a deliberate
/// brand moment rather than a flash that gets cut off mid-animation.
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.child,
    this.minDuration = const Duration(milliseconds: 1900),
  });

  final Widget child;
  final Duration minDuration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transitionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  late final Animation<double> _mapFade = CurvedAnimation(
    parent: _transitionController,
    curve: AppCurves.standard,
  );

  late final Animation<double> _mapScale = Tween<double>(begin: 1.03, end: 1.0)
      .animate(CurvedAnimation(
    parent: _transitionController,
    curve: AppCurves.standard,
  ));

  late final Animation<double> _splashFade = CurvedAnimation(
    parent: _transitionController,
    curve: const Interval(0.15, 1.0, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.minDuration, () {
      if (!mounted) return;
      _transitionController.forward();
    });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, _) {
        return Stack(
          children: [
            Transform.scale(
              scale: _mapScale.value,
              child: Opacity(opacity: _mapFade.value, child: widget.child),
            ),
            if (_transitionController.value < 1)
              IgnorePointer(
                child: Opacity(
                  opacity: 1 - _splashFade.value,
                  child: const SplashScreen(),
                ),
              ),
          ],
        );
      },
    );
  }
}
