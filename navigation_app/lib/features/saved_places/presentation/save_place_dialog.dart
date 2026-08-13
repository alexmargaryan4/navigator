import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/saved_place.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../application/saved_places_controller.dart';

/// Prompts for a label + quick icon and saves [place] via
/// [SavedPlacesController] (product spec "Сохранённые места" — the
/// user gives their own name, e.g. "Дом", "Работа"). The place's real
/// coordinates are whatever [place] already carries — never re-derived
/// here.
Future<void> showSavePlaceDialog(
  BuildContext context,
  WidgetRef ref,
  Place place,
) async {
  final controller = TextEditingController(text: place.name);
  var selectedIcon = SavedPlaceIcon.other;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final colors = Theme.of(dialogContext).appColors;
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Save place', style: TextStyle(color: colors.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: colors.onSurface),
                decoration: const InputDecoration(hintText: 'e.g. Home, Work'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SavedPlaceIcon.values.map((icon) {
                  final isSelected = icon == selectedIcon;
                  return Pressable(
                    onTap: () => setState(() => selectedIcon = icon),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSelected ? AppGradients.brandSubtle(colors) : null,
                        color: isSelected ? null : colors.inputFill,
                        border: Border.all(
                          color: isSelected
                              ? colors.accent.withOpacity(0.4)
                              : colors.divider,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _iconFor(icon),
                        size: 17,
                        color: isSelected ? colors.accent : colors.onSurfaceMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );

  if (confirmed != true) return;
  final label = controller.text.trim().isEmpty ? place.name : controller.text.trim();
  await ref
      .read(savedPlacesControllerProvider.notifier)
      .saveFromPlace(place, label: label, icon: selectedIcon);
}

IconData _iconFor(SavedPlaceIcon icon) => switch (icon) {
      SavedPlaceIcon.home => Icons.home_rounded,
      SavedPlaceIcon.work => Icons.work_rounded,
      SavedPlaceIcon.university => Icons.school_rounded,
      SavedPlaceIcon.restaurant => Icons.restaurant_rounded,
      SavedPlaceIcon.family => Icons.family_restroom_rounded,
      SavedPlaceIcon.star => Icons.star_rounded,
      SavedPlaceIcon.other => Icons.place_rounded,
    };
