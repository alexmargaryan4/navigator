import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/providers/location_providers.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../core/animation/motion_tokens.dart';
import '../../../core/permissions/location_permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/place.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/navigation/app_page_route.dart';
import '../../ai_navigation/presentation/ai_navigation_sheet.dart';
import '../../navigation/application/trip_controller.dart';
import '../../navigation/application/trip_state.dart';
import '../../navigation/presentation/navigation_hud.dart';
import '../../navigation/presentation/route_preview_sheet.dart';
import '../../parking/presentation/parking_screen.dart';
import '../../search/presentation/place_info_card.dart';
import '../../search/presentation/search_sheet.dart';
import '../../settings/presentation/settings_screen.dart';
import '../map_style.dart';
import '../mapbox_map_controller.dart';
import '../../traffic/presentation/traffic_toggle_button.dart';
import 'map_action_button.dart';

/// The root screen of the app — the map is the visual hero (spec §36),
/// with every other feature (search, route preview, navigation, AI,
/// parking) surfacing as a sheet or overlay on top of it rather than a
/// separate full page, so nothing ever feels disconnected from "the map
/// the user was just looking at" (spec §18, §20).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? _rawController;
  MapboxMapController? _controller;
  bool _stylesReady = false;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationPermissionProvider.notifier).request();
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    _rawController = controller;
    _controller = MapboxMapController(controller);
  }

  Future<void> _onStyleLoaded() async {
    await _controller?.initializeSources();
    if (!mounted) return;
    setState(() => _stylesReady = true);

    final brightness = Theme.of(context).brightness;
    await _controller?.setLightPreset(
      brightness == Brightness.dark
          ? MapStyle.lightPresetNight
          : MapStyle.lightPresetDay,
    );

    final last = await ref.read(lastKnownLocationProvider.future);
    if (last != null && mounted) {
      await _controller?.animateToLocation(
        GeoPoint(latitude: last.latitude, longitude: last.longitude),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final permissionState = ref.watch(locationPermissionProvider);
    final tripState = ref.watch(tripControllerProvider);

    ref.listen(tripControllerProvider, (previous, next) {
      _reactToTripChange(previous, next);
    });

    ref.listen(themeBrightnessProvider(context), (previous, next) {
      if (previous != next && _stylesReady) {
        _controller?.setLightPreset(
          next == Brightness.dark
              ? MapStyle.lightPresetNight
              : MapStyle.lightPresetDay,
        );
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              styleString: MapStyle.light,
              initialCameraPosition: const CameraPosition(
                target: LatLng(40.1792, 44.4991), // Yerevan — sensible default
                zoom: 12,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              myLocationEnabled: permissionState.valueOrNull ==
                  LocationPermissionState.granted,
              myLocationTrackingMode: MyLocationTrackingMode.tracking,
              myLocationRenderMode: MyLocationRenderMode.gps,
              compassEnabled: false,
              onCameraTrackingDismissed: () {
                if (tripState.isActive) {
                  ref.read(tripControllerProvider.notifier).setFollowingUser(false);
                }
              },
              onMapClick: (_, latLng) => _handleMapTap(latLng),
            ),
          ),

          // Permission prompt — shown as a dismissible, animated banner
          // rather than a blocking dialog, so the map is still usable.
          if (permissionState.valueOrNull ==
                  LocationPermissionState.deniedForever ||
              permissionState.valueOrNull ==
                  LocationPermissionState.serviceDisabled)
            _LocationPermissionBanner(state: permissionState.valueOrNull!),

          // Search bar / top chrome — hidden once navigation starts, so
          // the HUD owns the top of the screen instead.
          if (!tripState.isActive)
            AnimatedPositioned(
              duration: MotionTokens.current().pageTransition.duration,
              curve: MotionTokens.current().pageTransition.curve,
              top: tripState.phase == TripPhase.idle ? 56 : -80,
              left: 16,
              right: 16,
              child: _TopBar(
                onSearchTap: _openSearch,
                onMenuTap: _openSettings,
              ),
            ),

          // Destination info card — appears once a place is picked but
          // before routes are requested (spec §20-21 sequence).
          if (tripState.phase == TripPhase.destinationSelected &&
              tripState.destination != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: PlaceInfoCard(
                place: tripState.destination!,
                isCalculating: tripState.isCalculatingRoute,
                onStartRoute: () =>
                    ref.read(tripControllerProvider.notifier).calculateRoutes(),
                onDismiss: () =>
                    ref.read(tripControllerProvider.notifier).clearDestination(),
              ),
            ),

          // Route preview — alternatives + start-navigation CTA.
          if (tripState.phase == TripPhase.routePreview)
            RoutePreviewSheet(
              tripState: tripState,
              onSelectRoute: (id) =>
                  ref.read(tripControllerProvider.notifier).selectRoute(id),
              onSetMode: (mode) =>
                  ref.read(tripControllerProvider.notifier).setMode(mode),
              onStartNavigation: () =>
                  ref.read(tripControllerProvider.notifier).startNavigation(),
              onCancel: () =>
                  ref.read(tripControllerProvider.notifier).clearDestination(),
            ),

          // Active navigation HUD.
          if (tripState.isActive)
            NavigationHud(
              tripState: tripState,
              onRecenter: () {
                ref.read(tripControllerProvider.notifier).setFollowingUser(true);
              },
              onEnd: () => ref.read(tripControllerProvider.notifier).endTrip(),
            ),

          // Right-side floating controls (traffic / re-center) — hidden
          // during active navigation since the HUD owns re-centering.
          if (!tripState.isActive)
            Positioned(
              right: 16,
              bottom: tripState.phase == TripPhase.idle ? 32 : 220,
              child: _RightControls(
                controller: _controller,
                onOpenParking: _openParking,
                onOpenAi: _openAiSheet,
              ),
            ),
        ],
      ),
    );
  }

  void _reactToTripChange(TripState? previous, TripState next) async {
    if (_controller == null || !_stylesReady) return;

    // Destination newly selected -> marker + camera move (spec §20).
    if (next.destination != null &&
        previous?.destination?.id != next.destination!.id) {
      await _controller!.showDestinationMarker(next.destination!.location);
      await _controller!.flyToLocation(next.destination!.location);
    }
    if (next.destination == null && previous?.destination != null) {
      await _controller!.clearDestinationMarker();
      await _controller!.clearRoutes();
    }

    // Routes newly calculated -> draw + fit camera (spec §21).
    final gotNewRoutes = next.routes.isNotEmpty &&
        (previous == null || previous.routes.length != next.routes.length);
    if (gotNewRoutes) {
      await _controller!.showRoutes(next.routes);
      final primary = next.selectedRoute;
      if (primary != null) {
        await _controller!.fitToRoute(primary);
      }
    }

    // Entered navigation -> switch to follow camera (spec §22).
    if (next.isActive && previous?.isActive != true) {
      final origin = next.selectedRoute?.geometry.isNotEmpty == true
          ? next.selectedRoute!.geometry.first
          : null;
      if (origin != null) {
        await _controller!.enterNavigationCamera(origin, bearing: 0);
      }
    }

    // Left navigation -> restore standard camera + clear routes.
    if (!next.isActive && previous?.isActive == true) {
      await _controller!.clearRoutes();
      await _controller!.clearDestinationMarker();
    }
  }

  void _handleMapTap(LatLng point) {
    // Long-press-to-select-destination is intentionally out of scope
    // for a plain tap to avoid accidental destination changes while
    // panning; search remains the primary way to pick a destination.
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchSheet(),
    ).then((selected) {
      setState(() => _searchOpen = false);
      if (selected != null) {
        ref.read(tripControllerProvider.notifier).selectDestination(selected);
      }
    });
  }

  void _openAiSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiNavigationSheet(),
    );
  }

  void _openParking() {
    Navigator.of(context).push(
      AppPageRoute.slideUp(const ParkingScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      AppPageRoute.fadeSlide(const SettingsScreen()),
    );
  }
}

/// Reads [Theme.of(context).brightness] as a provider-friendly value so
/// it can participate in [WidgetRef.listen] alongside real providers.
Provider<Brightness> themeBrightnessProvider(BuildContext context) =>
    Provider<Brightness>((ref) => Theme.of(context).brightness);

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSearchTap, required this.onMenuTap});

  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: onSearchTap,
            borderRadius: BorderRadius.circular(28),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.search, color: colors.onSurfaceMuted, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Where to?',
                    style: TextStyle(color: colors.onSurfaceMuted, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Pressable(
          onTap: onMenuTap,
          borderRadius: BorderRadius.circular(28),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(14),
            child: Icon(Icons.menu_rounded, color: colors.onSurface, size: 22),
          ),
        ),
      ],
    );
  }
}

class _RightControls extends ConsumerWidget {
  const _RightControls({
    required this.controller,
    required this.onOpenParking,
    required this.onOpenAi,
  });

  final MapboxMapController? controller;
  final VoidCallback onOpenParking;
  final VoidCallback onOpenAi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MapActionButton(
          icon: Icons.auto_awesome,
          tooltip: 'AI navigation',
          onTap: onOpenAi,
        ),
        const SizedBox(height: 12),
        MapActionButton(
          icon: Icons.local_parking_rounded,
          tooltip: 'Parking',
          onTap: onOpenParking,
        ),
        const SizedBox(height: 12),
        TrafficToggleButton(controller: controller),
        const SizedBox(height: 12),
        MapActionButton(
          icon: Icons.my_location_rounded,
          tooltip: 'My location',
          onTap: () async {
            final last = await ref.read(lastKnownLocationProvider.future);
            if (last != null) {
              await controller?.animateToLocation(
                GeoPoint(latitude: last.latitude, longitude: last.longitude),
              );
            }
          },
        ),
      ],
    );
  }
}

class _LocationPermissionBanner extends ConsumerWidget {
  const _LocationPermissionBanner({required this.state});

  final LocationPermissionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).appColors;
    final message = state == LocationPermissionState.serviceDisabled
        ? 'Location services are off. Enable them to see your position.'
        : "Location access is off. Enable it in Settings to see your position.";

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedSlide(
          offset: Offset.zero,
          duration: MotionTokens.current().overlayFade.duration,
          child: GlassSurface(
            borderRadius: BorderRadius.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.location_off_rounded, color: colors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: colors.onSurface, fontSize: 13),
                  ),
                ),
                Pressable(
                  onTap: () {
                    final handler = ref.read(locationPermissionHandlerProvider);
                    if (state == LocationPermissionState.serviceDisabled) {
                      handler.openLocationSettings();
                    } else {
                      handler.openAppSettings();
                    }
                  },
                  child: Text(
                    'Fix',
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
