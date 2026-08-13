import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/location_providers.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/along_route_poi.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/place.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';
import '../../../shared/widgets/motion/staggered_fade_in.dart';
import '../application/ai_navigation_controller.dart';

/// The AI navigation panel (product spec §27, §44-48): a natural-
/// language input plus a microphone button, backed by
/// [AiNavigationController]. The panel itself only ever displays real
/// outcomes of that controller's pipeline — a resolved place, a
/// clarifying question, or a friendly failure — never a fabricated
/// route or ETA.
///
/// Opened as a modal bottom sheet from the map's floating AI button.
class AiNavigationSheet extends ConsumerStatefulWidget {
  const AiNavigationSheet({super.key});

  @override
  ConsumerState<AiNavigationSheet> createState() => _AiNavigationSheetState();
}

class _AiNavigationSheetState extends ConsumerState<AiNavigationSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _listening = false;
  double _soundLevel = 0;

  @override
  void initState() {
    super.initState();
    // Repaints the field's border color/width on focus change (see
    // search_sheet.dart for the same pattern) since the Material
    // InputDecoration border is disabled in favor of the themed
    // AnimatedContainer border below.
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (_listening) {
      ref.read(speechToTextServiceProvider).cancel();
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit([String? text]) {
    final value = (text ?? _controller.text).trim();
    if (value.isEmpty) return;
    ref.read(aiNavigationControllerProvider.notifier).submit(value);
  }

  void _confirmPlace(Place place) {
    ref.read(aiNavigationControllerProvider.notifier).confirmPlace(place);
  }

  Future<void> _toggleListening() async {
    final service = ref.read(speechToTextServiceProvider);

    if (_listening) {
      await service.stop();
      setState(() => _listening = false);
      return;
    }

    setState(() {
      _listening = true;
      _soundLevel = 0;
    });

    final result = await service.startListening(
      onUpdate: (update) {
        if (!mounted) return;
        setState(() {
          _controller.text = update.text;
          _soundLevel = update.soundLevel;
        });
        if (update.isFinal) {
          setState(() => _listening = false);
          _submit(update.text);
        }
      },
    );

    if (result.isErr && mounted) {
      setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();
    final state = ref.watch(aiNavigationControllerProvider);

    ref.listen(aiNavigationControllerProvider, (previous, next) {
      // A "done" outcome that produced along-route results (product spec
      // «По пути») has something to show right here in the sheet — only
      // auto-close for the plain "route started" outcome.
      if (next.phase == AiRequestPhase.done &&
          next.alongRoutePois.isEmpty &&
          mounted) {
        Navigator.of(context).maybePop();
      }
    });

    return AnimatedPadding(
      duration: motion.bottomSheet.duration,
      curve: motion.bottomSheet.curve,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.brand(colors),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accentShadow,
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.auto_awesome,
                          color: colors.onAccent, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI Navigation',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tell me where you want to go, in your own words.',
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildStatus(context, state, colors, motion),
                if (state.phase == AiRequestPhase.needsPlaceConfirmation) ...[
                  const SizedBox(height: 8),
                  _PlaceCandidateList(
                    candidates: state.candidates,
                    onSelect: _confirmPlace,
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.phase == AiRequestPhase.done &&
                    state.alongRoutePois.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _AlongRouteResultList(
                    category: state.alongRouteCategory,
                    pois: state.alongRoutePois,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: motion.microInteraction.duration,
                        decoration: BoxDecoration(
                          color: colors.inputFill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _focusNode.hasFocus
                                ? colors.inputBorderFocused
                                : colors.inputBorder,
                            width: _focusNode.hasFocus ? 1.8 : 1.3,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: TextStyle(color: colors.onSurface),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                            hintText: 'e.g. "Take me to the airport"',
                            hintStyle: TextStyle(color: colors.onSurfaceMuted),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _MicButton(
                      listening: _listening,
                      soundLevel: _soundLevel,
                      onTap: _toggleListening,
                    ),
                    const SizedBox(width: 10),
                    AppIconButton(
                      icon: Icons.arrow_upward_rounded,
                      onTap: _submit,
                      filled: true,
                      size: 48,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(
    BuildContext context,
    AiNavigationState state,
    AppColors colors,
    MotionTokens motion,
  ) {
    return AnimatedSwitcher(
      duration: motion.cardTransition.duration,
      switchInCurve: motion.cardTransition.curve,
      switchOutCurve: motion.cardTransition.curve,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: switch (state.phase) {
        AiRequestPhase.idle => const SizedBox.shrink(key: ValueKey('idle')),
        AiRequestPhase.thinking => const Padding(
            key: ValueKey('thinking'),
            padding: EdgeInsets.only(bottom: 4),
            child: ContextualLoadingIndicator(
              context_: LoadingContext.ai,
              compact: true,
            ),
          ),
        AiRequestPhase.resolving => const Padding(
            key: ValueKey('resolving'),
            padding: EdgeInsets.only(bottom: 4),
            child: ContextualLoadingIndicator(
              context_: LoadingContext.route,
              compact: true,
            ),
          ),
        AiRequestPhase.needsPlaceConfirmation => Padding(
            key: const ValueKey('confirm'),
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'A few places match — which one did you mean?',
              style: TextStyle(color: colors.onSurface, fontSize: 14),
            ),
          ),
        AiRequestPhase.needsClarification => Padding(
            key: const ValueKey('clarify'),
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              state.clarificationQuestion ?? 'Could you clarify that?',
              style: TextStyle(color: colors.onSurface, fontSize: 14),
            ),
          ),
        AiRequestPhase.failed => Padding(
            key: const ValueKey('failed'),
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              state.failure?.message ?? 'Something went wrong.',
              style: TextStyle(color: colors.error, fontSize: 14),
            ),
          ),
        AiRequestPhase.done => state.alongRoutePois.isNotEmpty
            ? Padding(
                key: const ValueKey('done-along-route'),
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${state.alongRoutePois.length} found along your route',
                  style: TextStyle(color: colors.onSurface, fontSize: 14),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('done')),
      },
    );
  }
}

/// Shown when the AI's destination text matched more than one plausible
/// real place (product spec «Защита от неправильных мест при
/// AI-поиске»): every candidate here came from the real hybrid search
/// pipeline, with its own name/address/real distance — the app never
/// silently picks one for the user.
class _PlaceCandidateList extends ConsumerWidget {
  const _PlaceCandidateList({required this.candidates, required this.onSelect});

  final List<Place> candidates;
  final ValueChanged<Place> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).appColors;
    final lastKnown = ref.watch(lastKnownLocationProvider);
    final sample = lastKnown.valueOrNull;

    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: candidates.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: colors.divider.withOpacity(0.5),
            indent: 20,
            endIndent: 20,
          ),
          itemBuilder: (context, index) {
            final place = candidates[index];
            double? distanceMeters;
            if (sample != null) {
              distanceMeters = place.location.distanceTo(
                GeoPoint(latitude: sample.latitude, longitude: sample.longitude),
              );
            }
            return StaggeredFadeIn(
              index: index,
              child: _PlaceCandidateTile(
                place: place,
                distanceMeters: distanceMeters,
                onTap: () => onSelect(place),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlaceCandidateTile extends StatelessWidget {
  const _PlaceCandidateTile({
    required this.place,
    required this.distanceMeters,
    required this.onTap,
  });

  final Place place;
  final double? distanceMeters;
  final VoidCallback onTap;

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

  String? get _distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.brandSubtle(colors),
                border: Border.all(
                  color: colors.accent.withOpacity(0.2),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(_icon, color: colors.accent, size: 17),
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
            if (_distanceLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                _distanceLabel!,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Real «По пути» results (product spec «По пути»): every entry here
/// came from [AlongRouteSearchService] and is genuinely close to the
/// active route's geometry, not merely close to the user.
class _AlongRouteResultList extends StatelessWidget {
  const _AlongRouteResultList({required this.category, required this.pois});

  final AlongRoutePoiCategory? category;
  final List<AlongRoutePoi> pois;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: pois.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: colors.divider.withOpacity(0.5),
            indent: 20,
            endIndent: 20,
          ),
          itemBuilder: (context, index) {
            final poi = pois[index];
            return StaggeredFadeIn(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (poi.address.isNotEmpty)
                            Text(
                              poi.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurfaceMuted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${poi.distanceFromRouteMeters.round()} m off route',
                      style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.soundLevel,
    required this.onTap,
  });

  final bool listening;
  final double soundLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      scaleAmount: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: 48,
        height: 48,
        padding: EdgeInsets.all(listening ? soundLevel * 3 : 0),
        decoration: BoxDecoration(
          color: listening ? colors.error.withOpacity(0.14) : null,
          shape: BoxShape.circle,
          border: Border.all(
            color: listening ? colors.error.withOpacity(0.6) : colors.divider,
            width: listening ? 1.6 : 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          listening ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: listening ? colors.error : colors.onSurfaceMuted,
          size: 20,
        ),
      ),
    );
  }
}
