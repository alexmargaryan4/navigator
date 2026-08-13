import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/route_stop.dart';
import '../../../domain/entities/travel_mode.dart';
import '../application/favorite_routes_controller.dart';

/// Prompts for a label and saves the current trip — real, already-
/// resolved [origin]/[destination]/[stops], never re-geocoded here — as
/// a new [FavoriteRoute] (product spec "Избранные маршруты", e.g. "Дом
/// → Работа").
Future<void> showSaveFavoriteRouteDialog(
  BuildContext context,
  WidgetRef ref, {
  required Place origin,
  required Place destination,
  List<RouteStop> stops = const [],
  TravelMode mode = TravelMode.driving,
}) async {
  final controller =
      TextEditingController(text: '${origin.name} → ${destination.name}');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).appColors;
      return AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Save route', style: TextStyle(color: colors.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.onSurface),
          decoration: const InputDecoration(hintText: 'e.g. Дом → Работа'),
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
  );

  if (confirmed != true) return;
  final label =
      controller.text.trim().isEmpty ? '${origin.name} → ${destination.name}' : controller.text.trim();
  await ref.read(favoriteRoutesControllerProvider.notifier).save(
        label: label,
        origin: origin,
        destination: destination,
        stops: stops,
        mode: mode,
      );
}
