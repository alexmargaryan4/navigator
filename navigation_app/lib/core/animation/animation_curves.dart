import 'package:flutter/animation.dart';

/// Centralized animation curve tokens.
///
/// Different interaction types deserve different curve "personalities" —
/// using the same curve everywhere is what makes an interface feel
/// mechanical. These map deliberately to specific interaction contexts.
abstract final class AppCurves {
  /// Quick, responsive feedback for taps and micro-interactions.
  static const Curve microInteraction = Curves.easeOut;

  /// Button press-down (fast) uses [buttonDown]; release uses [buttonUp].
  static const Curve buttonDown = Curves.easeOut;
  static const Curve buttonUp = Curves.easeOutBack;

  /// Standard UI element transitions (cards, panels, toggles).
  static const Curve standard = Curves.easeInOutCubic;

  /// Full-screen page transitions — Flutter's Material "fast out, slow in".
  static const Curve pageTransition = Curves.fastOutSlowIn;

  /// Bottom sheets and modals sliding into view.
  static const Curve sheetEnter = Curves.easeOutCubic;
  static const Curve sheetExit = Curves.easeInCubic;

  /// Map camera movement — smooth, slightly eased at both ends so the
  /// camera never feels like it "snaps" into place.
  static const Curve mapCamera = Curves.easeInOutCubic;

  /// GPS marker interpolation — linear-ish but slightly eased, since we
  /// want a steady sense of continuous movement, not a springy one.
  static const Curve locationMarker = Curves.linear;

  /// Bearing / rotation changes — eased so quick heading changes don't
  /// look jarring.
  static const Curve rotation = Curves.easeInOutSine;

  /// Route polyline draw-on.
  static const Curve routeDraw = Curves.easeInOutQuart;

  /// Elements that should feel like they're expanding from a point
  /// (search bar focus, AI panel opening).
  static const Curve expand = Curves.easeOutExpo;

  /// Elements collapsing back down.
  static const Curve collapse = Curves.easeInCubic;
}
