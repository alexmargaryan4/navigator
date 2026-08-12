import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/loading/loading_indicators.dart';
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
      if (next.phase == AiRequestPhase.done && mounted) {
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
        AiRequestPhase.done => const SizedBox.shrink(key: ValueKey('done')),
      },
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
