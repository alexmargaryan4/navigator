import 'package:flutter/material.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/nav_warning.dart';
import '../../../domain/entities/route.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/motion/animated_counter.dart';
import '../application/trip_state.dart';

/// The full-screen turn-by-turn overlay shown while [TripState.isActive]
/// (product spec §22-23, §50): a top maneuver card, a bottom ETA/
/// distance bar, and a floating re-center control — all reading directly
/// from live [TripState], so every number here traces back to real route
/// geometry and GPS progress rather than being invented.
class NavigationHud extends StatelessWidget {
  const NavigationHud({
    super.key,
    required this.tripState,
    required this.onRecenter,
    required this.onEnd,
  });

  final TripState tripState;
  final VoidCallback onRecenter;
  final VoidCallback onEnd;

  RouteStep? get _currentStep {
    final route = tripState.selectedRoute;
    if (route == null || route.steps.isEmpty) return null;
    final index = tripState.currentStepIndex.clamp(0, route.steps.length - 1);
    return route.steps[index];
  }

  IconData _maneuverIcon(String maneuverType) {
    if (maneuverType.contains('right')) return Icons.turn_right_rounded;
    if (maneuverType.contains('left')) return Icons.turn_left_rounded;
    if (maneuverType.contains('roundabout')) return Icons.roundabout_left_rounded;
    if (maneuverType.contains('arrive')) return Icons.flag_rounded;
    if (maneuverType.contains('merge')) return Icons.merge_rounded;
    return Icons.straight_rounded;
  }

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _etaLabel(double? remainingSeconds) {
    if (remainingSeconds == null) return '--:--';
    final eta = DateTime.now().add(Duration(seconds: remainingSeconds.round()));
    final hour = eta.hour.toString().padLeft(2, '0');
    final minute = eta.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _durationLabel(double? remainingSeconds) {
    if (remainingSeconds == null) return '--';
    final minutes = (remainingSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return '${hours}h ${rest}min';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();
    final step = _currentStep;

    return Stack(
      children: [
        // Top maneuver card.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: motion.cardTransition.duration,
              switchInCurve: motion.cardTransition.curve,
              switchOutCurve: motion.cardTransition.curve,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.15),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: step == null
                  ? const SizedBox.shrink(key: ValueKey('no-step'))
                  : Padding(
                      key: ValueKey('step-${tripState.currentStepIndex}'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: GlassSurface(
                        borderRadius: BorderRadius.circular(24),
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Icon(_maneuverIcon(step.maneuverType),
                                color: colors.accent, size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedCounter(
                                    value: tripState.remainingDistanceMeters ??
                                        step.distanceMeters,
                                    builder: (context, v) => Text(
                                      _distanceLabel(v),
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    step.roadName ?? step.instruction,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurfaceMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppIconButton(
                              icon: Icons.close_rounded,
                              onTap: onEnd,
                              size: 34,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),

        // Ahead-of-time warning card (product spec «Умные
        // предупреждения») — sits just under the maneuver card, only
        // ever built from real route data (see TripController._buildWarnings).
        if (_topWarning != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, step == null ? 12 : 96, 16, 0),
                child: AnimatedSwitcher(
                  duration: motion.cardTransition.duration,
                  switchInCurve: motion.cardTransition.curve,
                  switchOutCurve: motion.cardTransition.curve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _WarningCard(
                    key: ValueKey(_topWarning!.dedupeKey),
                    warning: _topWarning!,
                  ),
                ),
              ),
            ),
          ),

        // Speed readout: real GPS speed next to the real posted limit
        // (product spec «Ограничение скорости») — floats above the
        // bottom bar on the left, mirroring the re-center control's
        // position on the right.
        Positioned(
          left: 16,
          bottom: 132,
          child: SafeArea(
            top: false,
            child: _SpeedBadge(
              currentSpeedKph: tripState.currentSpeedKph,
              speedLimitKph: tripState.currentSpeedLimitKph,
              isSpeeding: tripState.isSpeeding,
            ),
          ),
        ),

        // Re-center control, floating just above the bottom bar.
        Positioned(
          right: 16,
          bottom: 132,
          child: AnimatedOpacity(
            opacity: tripState.isFollowingUser ? 0 : 1,
            duration: motion.microInteraction.duration,
            child: IgnorePointer(
              ignoring: tripState.isFollowingUser,
              child: AppIconButton(
                icon: Icons.my_location_rounded,
                onTap: onRecenter,
                filled: true,
                size: 48,
              ),
            ),
          ),
        ),

        // Bottom ETA / distance / duration bar.
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            top: false,
            child: GlassSurface(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _HudStat(
                    label: 'ETA',
                    value: _etaLabel(tripState.remainingDurationSeconds),
                    color: colors.onSurface,
                  ),
                  _HudStat(
                    label: 'Time',
                    value: _durationLabel(tripState.remainingDurationSeconds),
                    color: colors.accent,
                  ),
                  _HudStat(
                    label: 'Distance',
                    value: tripState.remainingDistanceMeters == null
                        ? '--'
                        : _distanceLabel(tripState.remainingDistanceMeters!),
                    color: colors.onSurface,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The single nearest real warning to surface as a card, or `null`
  /// when there is none right now — [TripState.activeWarnings] is
  /// already sorted nearest-first by the controller.
  NavWarning? get _topWarning =>
      tripState.activeWarnings.isEmpty ? null : tripState.activeWarnings.first;
}

/// Shows the user's real current speed next to the real posted speed
/// limit for the road they're on (product spec «Ограничение
/// скорости»). Either figure independently renders as "--" rather than
/// a fabricated number when the platform/provider hasn't supplied it —
/// this widget never invents a speed or a limit.
class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge({
    required this.currentSpeedKph,
    required this.speedLimitKph,
    required this.isSpeeding,
  });

  final double? currentSpeedKph;
  final double? speedLimitKph;
  final bool isSpeeding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Current speed — the app's own flat glass chip, matching
        // every other floating HUD surface.
        GlassSurface(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: AnimatedCounter(
            value: currentSpeedKph ?? 0,
            builder: (context, v) => Text(
              currentSpeedKph == null ? '--' : v.round().toString(),
              style: TextStyle(
                color: isSpeeding ? colors.error : colors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        // Real posted speed limit, styled like a physical speed-limit
        // sign — only rendered with a real number; a plain dash when
        // the provider has no data for this stretch (never guessed).
        if (speedLimitKph != null) ...[
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: motion.microInteraction.duration,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSpeeding ? colors.error : const Color(0xFFD64545),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: Text(
                  speedLimitKph!.round().toString(),
                  style: const TextStyle(
                    color: Color(0xFF12202B),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A single ahead-of-time warning card (product spec «Умные
/// предупреждения») — visual counterpart to the same event's voice
/// announcement (see TripController._announceWarnings), styled by
/// severity: traffic/speeding-relevant events use the warning/error
/// palette, plain upcoming-maneuver look-aheads use the neutral glass
/// surface so they don't visually compete with the primary maneuver
/// card above them.
class _WarningCard extends StatelessWidget {
  const _WarningCard({super.key, required this.warning});

  final NavWarning warning;

  (IconData, String) _content() {
    final distance = warning.distanceMeters < 1000
        ? '${warning.distanceMeters.round()} m'
        : '${(warning.distanceMeters / 1000).toStringAsFixed(1)} km';

    return switch (warning.type) {
      NavWarningType.upcomingTurn => (
          Icons.turn_slight_right_rounded,
          'Turn in $distance${warning.roadName != null ? ' onto ${warning.roadName}' : ''}',
        ),
      NavWarningType.complexIntersection => (
          Icons.roundabout_left_rounded,
          'Complex intersection in $distance',
        ),
      NavWarningType.upcomingExit => (
          Icons.moving_rounded,
          'Exit in $distance${warning.roadName != null ? ' — ${warning.roadName}' : ''}',
        ),
      NavWarningType.speedLimitChange => (
          Icons.speed_rounded,
          'Speed limit changes to ${warning.speedKph!.round()} km/h in $distance',
        ),
      NavWarningType.heavyTraffic => (
          Icons.traffic_rounded,
          'Heavy traffic in $distance',
        ),
    };
  }

  bool get _isAlert =>
      warning.type == NavWarningType.heavyTraffic ||
      warning.type == NavWarningType.speedLimitChange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final (icon, label) = _content();
    final accentColor = _isAlert ? colors.warning : colors.accent;

    return GlassSurface(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudStat extends StatelessWidget {
  const _HudStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
        ),
      ],
    );
  }
}
