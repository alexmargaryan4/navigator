import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';

/// A single circular floating action button used in the map's
/// right-side control stack (AI, parking, traffic, my-location).
///
/// Deliberately built on [Pressable] + [GlassSurface] rather than a
/// Material [IconButton] so every floating map control shares the same
/// premium press feedback and glass treatment (product spec §17, §26).
/// The active state uses the same brand gradient + hairline highlight
/// border as [AppButton] so every "on" surface in the app — buttons and
/// floating controls alike — reads as one consistent tone.
class MapActionButton extends StatelessWidget {
  const MapActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.isActive = false,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  /// Highlights the button (e.g. traffic toggle currently on) with the
  /// accent color instead of the neutral glass surface.
  final bool isActive;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;

    final button = Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      scaleAmount: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isActive ? AppGradients.brand(colors) : null,
          border: isActive
              ? Border.all(color: Colors.white.withOpacity(0.18), width: 1)
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors.accentShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: isActive
            ? Icon(icon, color: colors.onAccent, size: 22)
            : GlassSurface(
                borderRadius: BorderRadius.circular(size / 2),
                padding: EdgeInsets.zero,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(icon, color: colors.onSurface, size: 22),
                ),
              ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
