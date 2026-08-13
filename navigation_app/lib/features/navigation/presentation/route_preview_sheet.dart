import 'package:flutter/material.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/route_stop.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/layout/measure_size.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';
import '../../../shared/widgets/motion/staggered_fade_in.dart';
import '../application/trip_state.dart';

/// Shown once routes have been calculated for the current destination
/// (product spec §21, §40-41): a travel-mode selector, an editable stop
/// list (product spec "Маршрут с несколькими остановками"), the primary
/// route prominent with alternatives visually de-emphasized underneath,
/// and a "Start Navigation" call to action.
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
    this.onAddStop,
    this.onRemoveStop,
    this.onReorderStops,
    this.onSaveFavorite,
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

  /// Opens the search sheet to append a new stop before the final
  /// destination (product spec "добавлять остановки"). Omitted entirely
  /// hides the "Add stop" row.
  final VoidCallback? onAddStop;

  /// Removes the stop with this id (product spec "удалять остановки").
  final ValueChanged<String>? onRemoveStop;

  /// Reorders stops via drag-and-drop (product spec "менять порядок
  /// остановок drag-and-drop"); indices follow
  /// [ReorderableListView]'s own oldIndex/newIndex convention.
  final void Function(int oldIndex, int newIndex)? onReorderStops;

  /// Saves the current origin → stops → destination as a named favorite
  /// route (product spec "Избранные маршруты"). Omitted hides the
  /// bookmark action.
  final VoidCallback? onSaveFavorite;

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
                      if (onSaveFavorite != null)
                        AppIconButton(
                          icon: Icons.bookmark_border_rounded,
                          onTap: onSaveFavorite,
                          size: 34,
                        ),
                      const SizedBox(width: 6),
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
                  if (onAddStop != null || tripState.stops.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _StopsSection(
                      stops: tripState.stops,
                      onAddStop: onAddStop,
                      onRemoveStop: onRemoveStop,
                      onReorderStops: onReorderStops,
                    ),
                  ],
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

/// Editable list of intermediate stops (product spec "Маршрут с
/// несколькими остановками"): drag handles reorder, a trailing chip
/// removes, and a trailing row opens search to add another. Every stop
/// shown here is a real, already-geocoded [RouteStop.place] — nothing
/// here invents a location.
class _StopsSection extends StatelessWidget {
  const _StopsSection({
    required this.stops,
    this.onAddStop,
    this.onRemoveStop,
    this.onReorderStops,
  });

  final List<RouteStop> stops;
  final VoidCallback? onAddStop;
  final ValueChanged<String>? onRemoveStop;
  final void Function(int oldIndex, int newIndex)? onReorderStops;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stops.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              buildDefaultDragHandles: false,
              itemCount: stops.length,
              onReorder: (oldIndex, newIndex) =>
                  onReorderStops?.call(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final stop = stops[index];
                return _StopRow(
                  key: ValueKey(stop.id),
                  index: index,
                  stop: stop,
                  onRemove: onRemoveStop == null
                      ? null
                      : () => onRemoveStop!(stop.id),
                );
              },
            ),
          if (onAddStop != null)
            Pressable(
              onTap: onAddStop,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 18, color: colors.accent),
                    const SizedBox(width: 10),
                    Text(
                      'Add stop',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.index,
    required this.stop,
    this.onRemove,
  });

  final int index;
  final RouteStop stop;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_indicator_rounded,
                  size: 18, color: colors.onSurfaceMuted),
            ),
          ),
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent.withOpacity(0.14),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              stop.place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRemove != null)
            Pressable(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 16, color: colors.onSurfaceMuted),
              ),
            ),
        ],
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
