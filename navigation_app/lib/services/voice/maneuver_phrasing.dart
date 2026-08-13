import '../../domain/entities/route.dart';

/// Turns a real [RouteStep] (from the routing provider's own maneuver
/// data) into a natural-language phrase for text-to-speech.
///
/// This only rephrases fields the provider already returned
/// (`maneuverType`, `roadName`, `distanceMeters`) — it never invents a
/// maneuver, distance, or road name that the provider didn't supply.
abstract final class ManeuverPhrasing {
  /// e.g. "In 300 meters, turn right onto Main Street."
  static String upcoming(RouteStep step, {required double distanceMeters}) {
    final action = _actionPhrase(step.maneuverType);
    final road = step.roadName;
    final distance = _distancePhrase(distanceMeters);

    if (road == null || road.isEmpty) {
      return 'In $distance, $action.';
    }
    return 'In $distance, $action onto $road.';
  }

  /// e.g. "Turn right onto Main Street." — spoken right at the maneuver.
  static String immediate(RouteStep step) {
    final action = _actionPhrase(step.maneuverType);
    final road = step.roadName;
    if (road == null || road.isEmpty) {
      return '${_capitalize(action)}.';
    }
    return '${_capitalize(action)} onto $road.';
  }

  static const String arrived = 'You have arrived at your destination.';

  /// Spoken once when the user's real GPS speed first crosses the
  /// real posted limit for the road they're on — never phrased from a
  /// guessed limit (see [TripState.isSpeeding]).
  static String speedingWarning(double limitKph) =>
      'You are exceeding the speed limit of ${limitKph.round()} kilometers per hour.';

  /// Spoken once, ahead of time, for a real traffic-provider congestion
  /// segment on the active route (product spec «сильная пробка»).
  static const String heavyTrafficAhead = 'Heavy traffic ahead on your route.';

  /// Spoken once, ahead of time, for a real speed-limit change reported
  /// by the routing provider (product spec «изменение ограничения
  /// скорости»).
  static String speedLimitChangeAhead(double newLimitKph) =>
      'Speed limit changes to ${newLimitKph.round()} kilometers per hour ahead.';

  static String _distancePhrase(double meters) {
    if (meters < 50) return 'a moment';
    if (meters < 1000) {
      final rounded = (meters / 50).round() * 50;
      return '$rounded meters';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} kilometers';
  }

  static String _actionPhrase(String maneuverType) {
    final parts = maneuverType.split('-');
    final type = parts.isNotEmpty ? parts[0] : '';
    final modifier = parts.length > 1 ? parts[1] : '';

    return switch (type) {
      'turn' => switch (modifier) {
          'left' => 'turn left',
          'right' => 'turn right',
          'slight left' || 'slight-left' => 'bear left',
          'slight right' || 'slight-right' => 'bear right',
          'sharp left' || 'sharp-left' => 'make a sharp left',
          'sharp right' || 'sharp-right' => 'make a sharp right',
          'uturn' => 'make a U-turn',
          _ => 'turn',
        },
      'depart' => 'head out',
      'arrive' => 'arrive at your destination',
      'merge' => 'merge',
      'on ramp' || 'on-ramp' || 'onramp' => 'take the ramp',
      'off ramp' || 'off-ramp' || 'offramp' => 'take the exit',
      'fork' => modifier == 'left' ? 'keep left at the fork' : 'keep right at the fork',
      'roundabout' || 'rotary' => 'enter the roundabout',
      'continue' => 'continue straight',
      'new name' || 'new-name' => 'continue',
      _ => 'continue',
    };
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
