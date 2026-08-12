import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'splash_background.dart';
import 'splash_mark.dart';

/// The app's animated launch experience.
///
/// Replaces the previous plain-white gap between the native launch
/// screen and the map (there was no Flutter-level splash at all before
/// this — `MapScreen` was `home:` directly) with a full-tone brand
/// moment: slowly drifting gradient blobs in the same blue/teal palette
/// as the rest of the UI (see [AppColors]), a breathing brand mark, and
/// a coordinated fade + scale handoff into the real app driven by
/// `SplashGate` (see splash_gate.dart), which owns the actual timing of
/// when this screen is replaced.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Drives the drifting background blobs and the mark's ambient glow —
  // a single long, slowly-eased loop rather than several independently
  // timed controllers, so every motion on screen stays in phase and
  // never looks like it's "fighting" itself.
  late final AnimationController _ambientController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  // Drives the one-shot entrance: mark scales/fades in, then the
  // wordmark follows half a beat behind it.
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final Animation<double> _markScale = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0.0, 0.62, curve: Curves.easeOutBack),
  );

  late final Animation<double> _markFade = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
  );

  late final Animation<double> _wordmarkFade = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0.42, 0.85, curve: Curves.easeOut),
  );

  late final Animation<double> _wordmarkSlide = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0.42, 0.9, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _ambientController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Slowly drifting, softly blurred color fields in the brand's
          // blue/teal range — this is what keeps the screen from ever
          // reading as "just a dark/white screen with a logo": the tone
          // is alive without being distracting, and every color used
          // comes from the same two-hue family as the rest of the app.
          AnimatedBuilder(
            animation: _ambientController,
            builder: (context, _) => CustomPaint(
              painter: SplashBackgroundPainter(
                t: _ambientController.value,
                colors: colors,
                brightness: brightness,
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, _) => Opacity(
                    opacity: _markFade.value,
                    child: Transform.scale(
                      scale: 0.7 + (_markScale.value * 0.3),
                      child: AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, _) => SplashMark(
                          colors: colors,
                          breathe: math.sin(
                            _ambientController.value * 2 * math.pi,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, _) => Opacity(
                    opacity: _wordmarkFade.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - _wordmarkSlide.value) * 14),
                      child: child,
                    ),
                  ),
                  child: _Wordmark(colors: colors),
                ),
              ],
            ),
          ),

          // A thin, pulsing progress hint anchored to the bottom — never
          // a generic spinner (consistent with the app's contextual
          // loading philosophy elsewhere), just a quiet sign of life
          // while real initialization runs behind this screen.
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: AnimatedBuilder(
              animation: _entranceController,
              builder: (context, _) => Opacity(
                opacity: _wordmarkFade.value * 0.7,
                child: const _PulsingDots(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [colors.onSurface, colors.onSurface],
          ).createShader(bounds),
          child: Text(
            'Navigator',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Wherever you\'re headed',
          style: TextStyle(
            color: colors.onSurfaceMuted,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (_controller.value - (i * 0.18)) % 1.0;
            final t = phase < 0 ? phase + 1 : phase;
            final scale = 0.5 + (math.sin(t * math.pi).clamp(0, 1) * 0.5);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: (0.35 + scale * 0.65).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.6 + scale * 0.4,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.brand(colors),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
