/// Centralized animation duration tokens.
///
/// Every animated widget in the app should reference these constants
/// instead of hard-coding raw millisecond values. This keeps motion
/// consistent across features and makes global tuning trivial.
abstract final class AppDurations {
  /// Smallest possible feedback — button press scale/opacity, toggle flip.
  static const Duration microInteraction = Duration(milliseconds: 90);

  /// Button press down/up feedback.
  static const Duration buttonPress = Duration(milliseconds: 120);

  /// Small card state changes (e.g. a route card highlighting).
  static const Duration cardTransition = Duration(milliseconds: 220);

  /// Full-screen page transitions.
  static const Duration pageTransition = Duration(milliseconds: 320);

  /// Modal / dialog transitions.
  static const Duration modalTransition = Duration(milliseconds: 280);

  /// Bottom sheet open/close and resize.
  static const Duration bottomSheet = Duration(milliseconds: 300);

  /// Map camera movement for short, local repositioning (e.g. re-center).
  static const Duration mapCameraShort = Duration(milliseconds: 450);

  /// Map camera movement for long jumps (e.g. search result selected,
  /// destination is far from current viewport).
  static const Duration mapCameraLong = Duration(milliseconds: 900);

  /// Transition from route-preview mode into active turn-by-turn navigation.
  static const Duration navigationTransition = Duration(milliseconds: 520);

  /// GPS marker position interpolation between location updates.
  static const Duration locationMarkerMove = Duration(milliseconds: 500);

  /// GPS marker / map bearing rotation.
  static const Duration bearingRotation = Duration(milliseconds: 400);

  /// Route polyline "draw-on" animation.
  static const Duration routeDraw = Duration(milliseconds: 650);

  /// Stagger delay applied between successive alternative route cards.
  static const Duration routeCardStagger = Duration(milliseconds: 60);

  /// Search bar expand/collapse transform.
  static const Duration searchBarExpand = Duration(milliseconds: 260);

  /// Traffic / glass overlay fade in-out.
  static const Duration overlayFade = Duration(milliseconds: 200);

  /// Theme (light/dark) cross-fade.
  static const Duration themeTransition = Duration(milliseconds: 300);
}
