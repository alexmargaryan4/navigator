import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Context-aware loading states — never a single generic spinner
/// everywhere (product spec §29, §57). Each variant pairs a short label
/// with a lightweight, purposeful animated glyph.
enum LoadingContext { map, route, ai, parking, traffic, search }

extension _LoadingContextLabel on LoadingContext {
  String get label => switch (this) {
        LoadingContext.map => 'Loading map…',
        LoadingContext.route => 'Calculating route…',
        LoadingContext.ai => 'Thinking…',
        LoadingContext.parking => 'Searching nearby parking…',
        LoadingContext.traffic => 'Updating traffic…',
        LoadingContext.search => 'Searching…',
      };

  IconData get icon => switch (this) {
        LoadingContext.map => Icons.map_outlined,
        LoadingContext.route => Icons.alt_route,
        LoadingContext.ai => Icons.auto_awesome,
        LoadingContext.parking => Icons.local_parking_outlined,
        LoadingContext.traffic => Icons.traffic_outlined,
        LoadingContext.search => Icons.search,
      };
}

/// A compact, inline loading row: a gently pulsing icon + label.
///
/// Lightweight by design (a single [AnimationController]-driven opacity
/// pulse) so it stays performant even when shown over the live map.
class ContextualLoadingIndicator extends StatefulWidget {
  const ContextualLoadingIndicator({
    super.key,
    required this.context_,
    this.compact = false,
  });

  final LoadingContext context_;
  final bool compact;

  @override
  State<ContextualLoadingIndicator> createState() =>
      _ContextualLoadingIndicatorState();
}

class _ContextualLoadingIndicatorState
    extends State<ContextualLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    final icon = FadeTransition(
      opacity: pulse,
      child: RotationTransition(
        turns: widget.context_ == LoadingContext.ai
            ? Tween(begin: 0.0, end: 1.0).animate(_controller)
            : const AlwaysStoppedAnimation(0),
        child: Icon(
          widget.context_.icon,
          size: widget.compact ? 16 : 20,
          color: colors.accent,
        ),
      ),
    );

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            widget.context_.label,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 10),
          Text(
            widget.context_.label,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin, indeterminate progress bar for the top of the screen (e.g.
/// while traffic data refreshes in the background). Animates its own
/// opacity in/out rather than being conditionally inserted/removed
/// abruptly.
class TopProgressBar extends StatelessWidget {
  const TopProgressBar({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        height: 2,
        child: LinearProgressIndicator(
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation(colors.accent),
        ),
      ),
    );
  }
}
