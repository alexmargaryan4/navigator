import 'package:flutter/material.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/place.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';

/// Shown right after a destination is picked — before the user commits
/// to calculating routes (product spec §20-21: destination marker and
/// camera move happen first, then this card expands in).
class PlaceInfoCard extends StatelessWidget {
  const PlaceInfoCard({
    super.key,
    required this.place,
    required this.isCalculating,
    required this.onStartRoute,
    required this.onDismiss,
  });

  final Place place;
  final bool isCalculating;
  final VoidCallback onStartRoute;
  final VoidCallback onDismiss;

  IconData get _categoryIcon => switch (place.category) {
        PlaceCategory.restaurant => Icons.restaurant_rounded,
        PlaceCategory.shop => Icons.storefront_rounded,
        PlaceCategory.airport => Icons.flight_takeoff_rounded,
        PlaceCategory.hospital => Icons.local_hospital_rounded,
        PlaceCategory.gasStation => Icons.local_gas_station_rounded,
        PlaceCategory.landmark => Icons.account_balance_rounded,
        PlaceCategory.attraction => Icons.attractions_rounded,
        PlaceCategory.parking => Icons.local_parking_rounded,
        PlaceCategory.city => Icons.location_city_rounded,
        PlaceCategory.country => Icons.public_rounded,
        PlaceCategory.street => Icons.signpost_rounded,
        PlaceCategory.address => Icons.place_rounded,
        PlaceCategory.other => Icons.place_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();

    return TweenAnimationBuilder<double>(
      key: ValueKey(place.id),
      tween: Tween(begin: 0, end: 1),
      duration: motion.cardTransition.duration,
      curve: motion.cardTransition.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
      ),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.accent.withOpacity(0.12),
                  child: Icon(_categoryIcon, color: colors.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (place.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Pressable(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded,
                        color: colors.onSurfaceMuted, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCalculating ? null : onStartRoute,
                child: isCalculating
                    ? const ContextualLoadingIndicator(
                        context_: LoadingContext.route,
                        compact: true,
                      )
                    : const Text('Start Route'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
