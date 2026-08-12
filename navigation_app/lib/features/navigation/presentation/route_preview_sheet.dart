import 'package:flutter/material.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/layout/measure_size.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';
import '../../../shared/widgets/motion/staggered_fade_in.dart';
import '../application/trip_state.dart';

/// Shown once routes have been calculated for the current destination
/// (product spec §21, §40-41): a travel-mode selector, the primary route
/// prominent with alternatives visually de-emphasized underneath, and a
/// "Start Navigation" call to action.
///
/// This is a plain sheet anchored to the bottom of [MapScreen]'s stack
/// (not a modal) so the map stays fully visible and interactive behind
/// it, and slides/fades in as one coordinated motion rather than
/// appearing abruptly.
class RoutePreviewSheet extends StatelessWidget {
  const RoutePreviewSheet({
    super.key,
    required this.tripState,
    required this.onSelectRoute,
    required this.onSetMode,
    required this.onStartNavigation,
    required this.onCancel,
    this.onMeasured,
  });

  final TripState tripState;
  final ValueChanged<String> onSelectRoute;
  final ValueChanged<TravelMode> onSetMode;
  final VoidCallback onStartNavigation;
  final VoidCallback onCancel;

  /// Reports this sheet's actual rendered height (including its own
  /// bottom padding) after every layout pass, so callers positioning
  /// other floating UI above it (e.g. the map's right-side controls)
  /// can track its real size instead of guessing a fixed offset.
  final ValueChanged<double>? onMeasured;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();

    return Align(
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('route-preview-${tripState.routes.length}'),
        tween: Tween(begin: 0, end: 1),
        duration: motion.bottomSheet.duration,
        curve: motion.bottomSheet.curve,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 40),
            child: child,
          ),
        ),
        child: MeasureSize(
          onChange: (size) => onMeasured?.call(size.height),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tripState.destination?.name ?? 'Route',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AppIconButton(
                        icon: Icons.close_rounded,
                        onTap: onCancel,
                        size: 34,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ModeSelector(
                    selected: tripState.mode,
                    onSelect: onSetMode,
                  ),
                  const SizedBox(height: 14),
                  if (tripState.isCalculatingRoute)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: ContextualLoadingIndicator(
                        context_: LoadingContext.route,
                      ),
                    )
                  else if (tripState.failure != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        tripState.failure!.message,
                        style: TextStyle(color: colors.onSurfaceMuted),
                      ),
                    )
                  else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 190),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: tripState.routes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final route = tripState.routes[index];
                          final isSelected = route.id ==
                              (tripState.selectedRoute?.id ?? route.id);
                          return StaggeredFadeIn(
                            index: index,
                            child: _RouteCard(
                              route: route,
                              isSelected: isSelected,
                              onTap: () => onSelectRoute(route.id),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Start Navigation',
                      icon: Icons.navigation_rounded,
                      onTap: tripState.selectedRoute == null
                          ? null
                          : onStartNavigation,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onSelect});

  final TravelMode selected;
  final ValueChanged<TravelMode> onSelect;

  IconData _iconFor(TravelMode mode) => switch (mode) {
        TravelMode.driving => Icons.directions_car_rounded,
        TravelMode.walking => Icons.directions_walk_rounded,
        TravelMode.cycling => Icons.directions_bike_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Row(
      children: TravelMode.values.map((mode) {
        final isSelected = mode == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Pressable(
              onTap: () => onSelect(mode),
              borderRadius: BorderRadius.circular(16),
              scaleAmount: 0.96,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppGradients.brand(colors) : null,
                  color: isSelected ? null : colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withOpacity(0.16)
                        : colors.divider,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _iconFor(mode),
                      size: 20,
                      color: isSelected ? colors.onAccent : colors.onSurfaceMuted,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isSelected ? colors.onAccent : colors.onSurfaceMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  final NavRoute route;
  final bool isSelected;
  final VoidCallback onTap;

  String get _durationLabel {
    final minutes = (route.durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return '${hours}h ${rest}min';
  }

  String get _distanceLabel => route.distanceKm < 10
      ? '${route.distanceKm.toStringAsFixed(1)} km'
      : '${route.distanceKm.round()} km';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      scaleAmount: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppGradients.brandSubtle(colors) : null,
          color: isSelected ? null : colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        // Opacity de-emphasizes alternatives relative to the selected
        // route (spec §41) without hiding them outright.
        child: Opacity(
          opacity: isSelected ? 1 : 0.7,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _durationLabel,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (route.isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.success.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Fastest',
                              style: TextStyle(
                                color: colors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_distanceLabel${route.hasTolls ? ' • Tolls' : ''}',
                      style:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: colors.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
