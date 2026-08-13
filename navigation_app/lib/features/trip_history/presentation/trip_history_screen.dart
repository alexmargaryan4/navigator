import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../domain/entities/trip_history_entry.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';
import '../../../shared/widgets/motion/staggered_fade_in.dart';
import '../../navigation/application/trip_controller.dart';
import '../application/trip_history_controller.dart';

/// The trip history screen (product spec "История маршрутов"): every
/// entry is a real, previously-run trip — its distance/duration are the
/// routing provider's own figures at the time, recorded by
/// [TripController]. Tapping an entry re-launches navigation along the
/// same origin/stops/destination.
class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  Future<void> _relaunch(
    BuildContext context,
    WidgetRef ref,
    TripHistoryEntry entry,
  ) async {
    Navigator.of(context).popUntil((r) => r.isFirst);
    await ref.read(tripControllerProvider.notifier).startTripFromEndpoints(
          destinationPlace: entry.destination.toPlace(),
          stopPlaces: entry.stops.map((s) => s.toPlace()).toList(),
          mode: entry.mode,
        );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmClearDialog(),
    );
    if (confirmed != true) return;
    await ref.read(tripHistoryControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).appColors;
    final async = ref.watch(tripHistoryControllerProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Trip history',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  async.maybeWhen(
                    data: (entries) => entries.isEmpty
                        ? const SizedBox.shrink()
                        : AppIconButton(
                            icon: Icons.delete_outline_rounded,
                            onTap: () => _confirmClear(context, ref),
                            size: 40,
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: ContextualLoadingIndicator(context_: LoadingContext.route),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Couldn't load trip history.",
                      style: TextStyle(color: colors.onSurfaceMuted),
                    ),
                  ),
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return _EmptyState(colors: colors);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return StaggeredFadeIn(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TripHistoryCard(
                            entry: entry,
                            onTap: () => _relaunch(context, ref, entry),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({required this.entry, required this.onTap});

  final TripHistoryEntry entry;
  final VoidCallback onTap;

  String get _distanceLabel => entry.distanceKm < 10
      ? '${entry.distanceKm.toStringAsFixed(1)} km'
      : '${entry.distanceKm.round()} km';

  String get _durationLabel {
    final minutes = (entry.durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return '${hours}h ${rest}min';
  }

  String get _dateLabel => DateFormat('MMM d, HH:mm').format(entry.date);

  IconData get _modeIcon => switch (entry.mode) {
        TravelMode.driving => Icons.directions_car_rounded,
        TravelMode.walking => Icons.directions_walk_rounded,
        TravelMode.cycling => Icons.directions_bike_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.brandSubtle(colors),
                    border: Border.all(
                      color: colors.accent.withOpacity(0.22),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_modeIcon, color: colors.accent, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.destination.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'from ${entry.origin.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (entry.status == TripHistoryStatus.completed
                            ? colors.success
                            : colors.warning)
                        .withOpacity(0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.status == TripHistoryStatus.completed
                        ? 'Completed'
                        : 'Started',
                    style: TextStyle(
                      color: entry.status == TripHistoryStatus.completed
                          ? colors.success
                          : colors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (entry.stops.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Via ${entry.stops.map((s) => s.name).join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _distanceLabel,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _durationLabel,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _dateLabel,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmClearDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return AlertDialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Clear trip history?', style: TextStyle(color: colors.onSurface)),
      content: Text(
        'This can\'t be undone.',
        style: TextStyle(color: colors.onSurfaceMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Clear', style: TextStyle(color: colors.error)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, color: colors.onSurfaceMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              'No trips yet',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Trips you start or complete will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
