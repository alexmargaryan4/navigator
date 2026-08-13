import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/saved_place.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';
import '../../../shared/widgets/motion/staggered_fade_in.dart';
import '../../navigation/application/trip_controller.dart';
import '../application/saved_places_controller.dart';

/// The saved places screen (product spec "Сохранённые места"): every
/// entry is a real, previously-resolved place the user chose to save —
/// open it on the map, route to it, rename it, or delete it.
class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  void _openOnMap(BuildContext context, WidgetRef ref, SavedPlace place) {
    ref
        .read(tripControllerProvider.notifier)
        .selectDestination(place.toPlace());
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _startRoute(
    BuildContext context,
    WidgetRef ref,
    SavedPlace place,
  ) async {
    final tripController = ref.read(tripControllerProvider.notifier);
    tripController.selectDestination(place.toPlace());
    Navigator.of(context).popUntil((route) => route.isFirst);
    await tripController.calculateRoutes();
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, SavedPlace place) async {
    final controller = TextEditingController(text: place.label);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(controller: controller),
    );
    if (newLabel == null || newLabel.trim().isEmpty) return;
    await ref
        .read(savedPlacesControllerProvider.notifier)
        .rename(place.id, newLabel.trim());
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavedPlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDeleteDialog(label: place.label),
    );
    if (confirmed != true) return;
    await ref.read(savedPlacesControllerProvider.notifier).delete(place.id);
  }

  void _showActions(BuildContext context, WidgetRef ref, SavedPlace place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PlaceActionsSheet(
        place: place,
        onOpenMap: () {
          Navigator.of(sheetContext).pop();
          _openOnMap(context, ref, place);
        },
        onRoute: () {
          Navigator.of(sheetContext).pop();
          _startRoute(context, ref, place);
        },
        onRename: () {
          Navigator.of(sheetContext).pop();
          _rename(context, ref, place);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _delete(context, ref, place);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).appColors;
    final async = ref.watch(savedPlacesControllerProvider);

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
                    'Saved places',
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
                  child: ContextualLoadingIndicator(context_: LoadingContext.search),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Couldn't load saved places.",
                      style: TextStyle(color: colors.onSurfaceMuted),
                    ),
                  ),
                ),
                data: (places) {
                  if (places.isEmpty) {
                    return _EmptyState(colors: colors);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    itemCount: places.length,
                    itemBuilder: (context, index) {
                      final place = places[index];
                      return StaggeredFadeIn(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SavedPlaceCard(
                            place: place,
                            onTap: () => _showActions(context, ref, place),
                            onRoute: () => _startRoute(context, ref, place),
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

class _SavedPlaceCard extends StatelessWidget {
  const _SavedPlaceCard({
    required this.place,
    required this.onTap,
    required this.onRoute,
  });

  final SavedPlace place;
  final VoidCallback onTap;
  final VoidCallback onRoute;

  IconData get _icon => switch (place.icon) {
        SavedPlaceIcon.home => Icons.home_rounded,
        SavedPlaceIcon.work => Icons.work_rounded,
        SavedPlaceIcon.university => Icons.school_rounded,
        SavedPlaceIcon.restaurant => Icons.restaurant_rounded,
        SavedPlaceIcon.family => Icons.family_restroom_rounded,
        SavedPlaceIcon.star => Icons.star_rounded,
        SavedPlaceIcon.other => Icons.place_rounded,
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
              child: Icon(_icon, color: colors.accent, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (place.address.isNotEmpty)
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: onRoute,
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
                child: Icon(Icons.directions_rounded, color: colors.accent, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceActionsSheet extends StatelessWidget {
  const _PlaceActionsSheet({
    required this.place,
    required this.onOpenMap,
    required this.onRoute,
    required this.onRename,
    required this.onDelete,
  });

  final SavedPlace place;
  final VoidCallback onOpenMap;
  final VoidCallback onRoute;
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
                    place.label,
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
                icon: Icons.map_rounded,
                label: 'Show on map',
                onTap: onOpenMap,
              ),
              _ActionTile(
                icon: Icons.directions_rounded,
                label: 'Start route',
                onTap: onRoute,
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
      title: Text('Rename place', style: TextStyle(color: colors.onSurface)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: colors.onSurface),
        decoration: const InputDecoration(hintText: 'e.g. Home, Work'),
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
            Icon(Icons.bookmark_border_rounded, color: colors.onSurfaceMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              'No saved places yet',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Save a place from search or the map to find it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
