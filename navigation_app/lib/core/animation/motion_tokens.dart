import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';

import 'animation_curves.dart';
import 'animation_durations.dart';

/// A single (duration, curve) pair for a specific motion context.
class MotionSpec {
  const MotionSpec(this.duration, this.curve);

  final Duration duration;
  final Curve curve;

  /// Returns a copy of this spec scaled down for reduced-motion mode.
  ///
  /// Reduced motion does not disable animation entirely (a hard cut is
  /// often more jarring than a very short animation) — instead it
  /// shortens the duration and flattens the curve toward linear/easeOut.
  MotionSpec reduced() {
    final scaledMs = (duration.inMilliseconds * 0.35).clamp(60, 999).toInt();
    return MotionSpec(Duration(milliseconds: scaledMs), Curves.easeOut);
  }
}

/// Semantic motion tokens used throughout the app.
///
/// Widgets should ask for `MotionTokens.of(context).buttonPress` rather
/// than importing [AppDurations]/[AppCurves] directly, so that the
/// reduced-motion preference is automatically respected everywhere.
class MotionTokens {
  const MotionTokens({required this.reducedMotion});

  final bool reducedMotion;

  /// Reads the platform's "reduce motion" accessibility flag.
  /// Falls back to `false` if unavailable.
  static bool platformPrefersReducedMotion() {
    try {
      return SchedulerBinding
              .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    } catch (_) {
      return false;
    }
  }

  static MotionTokens current() =>
      MotionTokens(reducedMotion: platformPrefersReducedMotion());

  MotionSpec _spec(Duration d, Curve c) {
    final base = MotionSpec(d, c);
    return reducedMotion ? base.reduced() : base;
  }

  MotionSpec get microInteraction =>
      _spec(AppDurations.microInteraction, AppCurves.microInteraction);

  MotionSpec get buttonPress =>
      _spec(AppDurations.buttonPress, AppCurves.buttonDown);

  MotionSpec get cardTransition =>
      _spec(AppDurations.cardTransition, AppCurves.standard);

  MotionSpec get pageTransition =>
      _spec(AppDurations.pageTransition, AppCurves.pageTransition);

  MotionSpec get modalTransition =>
      _spec(AppDurations.modalTransition, AppCurves.standard);

  MotionSpec get bottomSheet =>
      _spec(AppDurations.bottomSheet, AppCurves.sheetEnter);

  MotionSpec get mapCameraShort =>
      _spec(AppDurations.mapCameraShort, AppCurves.mapCamera);

  MotionSpec get mapCameraLong =>
      _spec(AppDurations.mapCameraLong, AppCurves.mapCamera);

  MotionSpec get navigationTransition =>
      _spec(AppDurations.navigationTransition, AppCurves.standard);

  MotionSpec get locationMarkerMove =>
      _spec(AppDurations.locationMarkerMove, AppCurves.locationMarker);

  MotionSpec get bearingRotation =>
      _spec(AppDurations.bearingRotation, AppCurves.rotation);

  MotionSpec get routeDraw =>
      _spec(AppDurations.routeDraw, AppCurves.routeDraw);

  MotionSpec get searchBarExpand =>
      _spec(AppDurations.searchBarExpand, AppCurves.expand);

  MotionSpec get overlayFade =>
      _spec(AppDurations.overlayFade, AppCurves.standard);

  MotionSpec get themeTransition =>
      _spec(AppDurations.themeTransition, AppCurves.standard);

  Duration get routeCardStagger => reducedMotion
      ? Duration.zero
      : AppDurations.routeCardStagger;
}
