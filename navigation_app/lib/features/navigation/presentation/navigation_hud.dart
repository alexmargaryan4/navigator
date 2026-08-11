import 'package:flutter/material.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/route.dart';
import '../../../shared/widgets/buttons/pressable.dart';
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
                            Pressable(
                              onTap: onEnd,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(Icons.close_rounded,
                                    color: colors.onSurfaceMuted, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
              child: Pressable(
                onTap: onRecenter,
                borderRadius: BorderRadius.circular(24),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.my_location_rounded,
                      color: colors.accent, size: 22),
                ),
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
