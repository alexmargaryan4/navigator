import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/parking_spot.dart';
import '../../../domain/entities/place.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';
import '../../../shared/widgets/motion/staggered_fade_in.dart';
import '../../navigation/application/trip_controller.dart';
import '../application/parking_controller.dart';

/// Dedicated Parking feature (product spec §43): a real, provider-backed
/// list of nearby parking, opened as a full screen (via
/// [AppPageRoute.slideUp]) rather than a small sheet, since parking
/// results often need to be browsed and compared before picking one.
///
/// Selecting a spot starts a normal driving trip to it through the same
/// [TripController] the map uses for any other destination — parking is
/// just a specialized [Place] source, not a separate navigation path.
class ParkingScreen extends ConsumerWidget {
  const ParkingScreen({super.key});

  Place _toPlace(ParkingSpot spot) => Place(
        id: spot.id,
        name: spot.name,
        address: spot.address,
        location: spot.location,
        category: PlaceCategory.parking,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).appColors;
    final state = ref.watch(parkingControllerProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Nearby parking',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  AppIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () =>
                        ref.read(parkingControllerProvider.notifier).refresh(),
                    size: 40,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context, ref, state, colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ParkingState state,
    AppColors colors,
  ) {
    if (state.isLoading && state.spots.isEmpty) {
      return const Center(
        child: ContextualLoadingIndicator(context_: LoadingContext.parking),
      );
    }

    if (state.failure != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_parking_outlined,
                  color: colors.onSurfaceMuted, size: 36),
              const SizedBox(height: 12),
              Text(
                state.failure!.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceMuted),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                expand: false,
                onTap: () =>
                    ref.read(parkingControllerProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      );
    }

    if (state.spots.isEmpty) {
      return Center(
        child: Text(
          'No parking found nearby.',
          style: TextStyle(color: colors.onSurfaceMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: state.spots.length,
      itemBuilder: (context, index) {
        final spot = state.spots[index];
        return StaggeredFadeIn(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ParkingCard(
              spot: spot,
              onNavigate: () {
                ref
                    .read(tripControllerProvider.notifier)
                    .selectDestination(_toPlace(spot));
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }
}

class _ParkingCard extends StatelessWidget {
  const _ParkingCard({required this.spot, required this.onNavigate});

  final ParkingSpot spot;
  final VoidCallback onNavigate;

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.98, end: 1),
      duration: motion.cardTransition.duration,
      curve: motion.cardTransition.curve,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Icon(Icons.local_parking_rounded,
                  color: colors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (spot.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      spot.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (spot.distanceMeters != null)
                        _InfoChip(
                          icon: Icons.social_distance_rounded,
                          label: _distanceLabel(spot.distanceMeters!),
                        ),
                      if (spot.priceInfo != null)
                        _InfoChip(icon: Icons.payments_rounded, label: spot.priceInfo!),
                      if (spot.openingHours != null)
                        _InfoChip(
                            icon: Icons.schedule_rounded, label: spot.openingHours!),
                      if (spot.rating != null)
                        _InfoChip(
                          icon: Icons.star_rounded,
                          label: spot.rating!.toStringAsFixed(1),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: Icons.navigation_rounded,
              onTap: onNavigate,
              filled: true,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.onSurfaceMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
        ),
      ],
    );
  }
}
