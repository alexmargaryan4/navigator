import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/location_providers.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../core/animation/motion_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/location/location_tracker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/place.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';
import '../../../shared/widgets/motion/staggered_fade_in.dart';
import '../application/search_controller.dart';

/// Full-height search experience, opened as a modal bottom sheet from
/// the map (product spec §19, §39). Focusing the field expands the
/// sheet's own presence smoothly rather than swapping widgets outright;
/// results cascade in with [StaggeredFadeIn] instead of popping in as a
/// single block.
///
/// Returns the selected [Place] via `Navigator.pop` — the caller (the
/// map screen) is responsible for driving the destination-selection
/// sequence once a result comes back.
class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key});

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    // Open with the keyboard already up — the person tapped "Where to?"
    // specifically to type, so don't make them tap again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  GeoPoint? _proximity(AsyncValue<LocationSample?> lastKnown) {
    final value = lastKnown.valueOrNull;
    if (value == null) return null;
    return GeoPoint(latitude: value.latitude, longitude: value.longitude);
  }

  /// `/suggest` results carry a placeholder (0, 0) location — the real
  /// coordinates only come back from Search Box `/retrieve`. Resolving
  /// here, before popping the sheet, is what makes the destination
  /// marker/camera/route land on the actual picked place instead of
  /// always snapping to (0, 0).
  Future<void> _selectResult(Place place) async {
    setState(() => _resolving = true);

    final repo = ref.read(searchRepositoryProvider);
    final result = await repo.retrieveSuggestion(place.id);

    if (!mounted) return;
    setState(() => _resolving = false);

    result.when(
      ok: (resolved) => Navigator.of(context).pop(resolved),
      err: (f) => _showResolveError(f),
    );
  }

  void _showResolveError(AppFailure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();
    final searchState = ref.watch(searchControllerProvider);
    final lastKnown = ref.watch(lastKnownLocationProvider);

    return AnimatedPadding(
      duration: motion.bottomSheet.duration,
      curve: motion.bottomSheet.curve,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassSurface(
                          borderRadius: BorderRadius.circular(20),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(Icons.search,
                                  color: colors.onSurfaceMuted, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  autofocus: true,
                                  style: TextStyle(color: colors.onSurface),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText:
                                        'Search for a place, address, city…',
                                    hintStyle:
                                        TextStyle(color: colors.onSurfaceMuted),
                                  ),
                                  onChanged: (q) => ref
                                      .read(searchControllerProvider.notifier)
                                      .onQueryChanged(
                                        q,
                                        proximity: _proximity(lastKnown),
                                      ),
                                ),
                              ),
                              if (_controller.text.isNotEmpty)
                                Pressable(
                                  onTap: () {
                                    _controller.clear();
                                    ref
                                        .read(searchControllerProvider.notifier)
                                        .clear();
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: colors.onSurfaceMuted, size: 18),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Pressable(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody(searchState, colors)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(SearchState state, AppColors colors) {
    if (state.isLoading && state.results.isEmpty) {
      return const Center(
        child: ContextualLoadingIndicator(context_: LoadingContext.search),
      );
    }

    if (state.failure != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.failure!.message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceMuted),
          ),
        ),
      );
    }

    if (state.query.isEmpty) {
      return Center(
        child: Text(
          'Search for addresses, restaurants, airports, and more.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
        ),
      );
    }

    if (state.results.isEmpty && !state.isLoading) {
      return Center(
        child: Text(
          'No results for "${state.query}"',
          style: TextStyle(color: colors.onSurfaceMuted),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.results.length,
          itemBuilder: (context, index) {
            final place = state.results[index];
            return StaggeredFadeIn(
              index: index,
              child: _SearchResultTile(
                place: place,
                onTap: _resolving ? null : () => _selectResult(place),
              ),
            );
          },
        ),
        if (_resolving)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x22000000),
              child: Center(
                child: ContextualLoadingIndicator(context_: LoadingContext.search),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.place, required this.onTap});

  final Place place;
  final VoidCallback? onTap;

  IconData get _icon => switch (place.category) {
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
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.accent.withOpacity(0.12),
              child: Icon(_icon, color: colors.accent, size: 18),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (place.address.isNotEmpty)
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
