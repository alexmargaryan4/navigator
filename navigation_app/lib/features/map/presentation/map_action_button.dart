import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';

/// A single circular floating action button used in the map's
/// right-side control stack (AI, parking, traffic, my-location).
///
/// Built on [Pressable] + [GlassSurface] so every floating map control
/// shares the same press feedback and the same flat neutral surface
/// used everywhere else in the app (product spec §17). The active
/// state uses the same brand gradient + hairline highlight border as
/// [AppButton] so every "on" surface in the app — buttons and floating
/// controls alike — reads as one consistent tone.
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

        duration: const Duration(milliseconds: 240),

        curve: Curves.easeOutCubic,

        width: size,

        height: size,

        decoration: BoxDecoration(

          shape: BoxShape.circle,

          boxShadow: [

            BoxShadow(

              color: Colors.black.withOpacity(

                isActive ? 0.16 : 0.10,

              ),

              blurRadius: isActive ? 18 : 14,

              offset: const Offset(0, 6),

              spreadRadius: -4,

            ),

            if (isActive)

              BoxShadow(

                color: colors.accentShadow.withOpacity(0.30),

                blurRadius: 16,

                offset: const Offset(0, 3),

                spreadRadius: -5,

              ),

          ],

        ),

        child: ClipOval(

          child: BackdropFilter(

            // Deliberately low blur — the background should remain visible.

            filter: ImageFilter.blur(

              sigmaX: 2,

              sigmaY: 2,

            ),

            child: DecoratedBox(

              decoration: BoxDecoration(

                shape: BoxShape.circle,

                gradient: isActive

                    ? LinearGradient(

                        begin: const Alignment(-0.7, -1),

                        end: const Alignment(0.8, 1),

                        colors: [

                          colors.accent.withOpacity(0.92),

                          colors.accent.withOpacity(0.72),

                        ],

                      )

                    : LinearGradient(

                        begin: const Alignment(-0.8, -1),

                        end: const Alignment(0.8, 1),

                        colors: [

                          Colors.white.withOpacity(0.12),

                          Colors.white.withOpacity(0.045),

                        ],

                      ),

                border: Border.all(

                  color: Colors.white.withOpacity(

                    isActive ? 0.28 : 0.20,

                  ),

                  width: 0.8,

                ),

              ),

              child: Stack(

                fit: StackFit.expand,

                children: [

                  // Soft top-left glass reflection.

                  IgnorePointer(

                    child: DecoratedBox(

                      decoration: BoxDecoration(

                        shape: BoxShape.circle,

                        gradient: RadialGradient(

                          center: const Alignment(-0.55, -0.65),

                          radius: 0.85,

                          colors: [
  Colors.white.withOpacity(0.10),
  Colors.white.withOpacity(0.0),
],

                        ),

                      ),

                    ),

                  ),

                  // Very subtle bottom glass depth.

                  IgnorePointer(

                    child: DecoratedBox(

                      decoration: BoxDecoration(

                        shape: BoxShape.circle,

                        gradient: LinearGradient(

                          begin: Alignment.topCenter,

                          end: Alignment.bottomCenter,

                          colors: [

                            Colors.transparent,

                            Colors.black.withOpacity(

                              isActive ? 0.06 : 0.035,

                            ),

                          ],

                        ),

                      ),

                    ),

                  ),

                  Center(

                    child: AnimatedSwitcher(

                      duration: const Duration(milliseconds: 180),

                      switchInCurve: Curves.easeOutBack,

                      switchOutCurve: Curves.easeIn,

                      transitionBuilder: (child, animation) {

                        return FadeTransition(

                          opacity: animation,

                          child: ScaleTransition(

                            scale: Tween<double>(

                              begin: 0.82,

                              end: 1,

                            ).animate(animation),

                            child: child,

                          ),

                        );

                      },

                      child: Icon(

                        icon,

                        key: ValueKey('$icon-$isActive'),

                        size: 22,

                        color: isActive

                            ? colors.onAccent

                            : colors.onSurface,

                      ),

                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

    if (tooltip == null) {

      return button;

    }

    return Tooltip(

      message: tooltip!,

      child: button,

    );

  }
}
