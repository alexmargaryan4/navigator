import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/favorite_route.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';
import '../../../shared/widgets/motion/staggered_fade_in.dart';
import '../../navigation/application/trip_controller.dart';
import '../application/favorite_routes_controller.dart';

/// The favorite routes screen (product spec "Избранные маршруты"):
/// every entry is a whole saved trip — origin, destination, and any
/// stops — that launches with one tap through the same
/// [TripController.startTripFromEndpoints] the AI navigator uses, so
/// this is just another real front door to the same pipeline.
class FavoriteRoutesScreen extends ConsumerWidget {
  const FavoriteRoutesScreen({super.key});

  Future<void> _launch(
    BuildContext context,
    WidgetRef ref,
    FavoriteRoute route,
  ) async {
    Navigator.of(context).popUntil((r) => r.isFirst);
    await ref.read(tripControllerProvider.notifier).startTripFromEndpoints(
          destinationPlace: route.destination.toPlace(),
          stopPlaces: route.stops.map((s) => s.toPlace()).toList(),
          mode: route.mode,
        );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    FavoriteRoute route,
  ) async {
    final controller = TextEditingController(text: route.label);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(controller: controller),
    );
    if (newLabel == null || newLabel.trim().isEmpty) return;
    await ref
        .read(favoriteRoutesControllerProvider.notifier)
        .rename(route.id, newLabel.trim());
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FavoriteRoute route,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDeleteDialog(label: route.label),
    );
    if (confirmed != true) return;
    await ref.read(favoriteRoutesControllerProvider.notifier).delete(route.id);
  }

  void _showActions(BuildContext context, WidgetRef ref, FavoriteRoute route) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RouteActionsSheet(
        route: route,
        onStart: () {
          Navigator.of(sheetContext).pop();
          _launch(context, ref, route);
        },
        onRename: () {
          Navigator.of(sheetContext).pop();
          _rename(context, ref, route);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _delete(context, ref, route);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).appColors;
    final async = ref.watch(favoriteRoutesControllerProvider);

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
                  Text(
                    'Favorite routes',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
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
                      "Couldn't load favorite routes.",
                      style: TextStyle(color: colors.onSurfaceMuted),
                    ),
                  ),
                ),
                data: (routes) {
                  if (routes.isEmpty) {
                    return _EmptyState(colors: colors);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      return StaggeredFadeIn(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FavoriteRouteCard(
                            route: route,
                            onTap: () => _showActions(context, ref, route),
                            onStart: () => _launch(context, ref, route),
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

class _FavoriteRouteCard extends StatelessWidget {
  const _FavoriteRouteCard({
    required this.route,
    required this.onTap,
    required this.onStart,
  });

  final FavoriteRoute route;
  final VoidCallback onTap;
  final VoidCallback onStart;

  String get _stopsSuffix =>
      route.stops.isEmpty ? '' : ' • ${route.stops.length} stop${route.stops.length == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.brandSubtle(colors),
                border: Border.all(
                  color: colors.accent.withOpacity(0.22),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.route_rounded, color: colors.accent, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${route.origin.name} → ${route.destination.name}$_stopsSuffix',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: onStart,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.inputFill,
                  border: Border.all(color: colors.divider, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.navigation_rounded, color: colors.accent, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteActionsSheet extends StatelessWidget {
  const _RouteActionsSheet({
    required this.route,
    required this.onStart,
    required this.onRename,
    required this.onDelete,
  });

  final FavoriteRoute route;
  final VoidCallback onStart;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    route.label,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _ActionTile(
                icon: Icons.navigation_rounded,
                label: 'Start route',
                onTap: onStart,
              ),
              _ActionTile(
                icon: Icons.edit_rounded,
                label: 'Rename',
                onTap: onRename,
              ),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                onTap: onDelete,
                destructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final color = destructive ? colors.error : colors.onSurface;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameDialog extends StatelessWidget {
  const _RenameDialog({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return AlertDialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Rename route', style: TextStyle(color: colors.onSurface)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: colors.onSurface),
        decoration: const InputDecoration(hintText: 'e.g. Дом → Работа'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return AlertDialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Delete "$label"?', style: TextStyle(color: colors.onSurface)),
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
          child: Text('Delete', style: TextStyle(color: colors.error)),
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
            Icon(Icons.route_rounded, color: colors.onSurfaceMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              'No favorite routes yet',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Save a route from the route preview screen to find it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
