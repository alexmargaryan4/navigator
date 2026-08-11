import 'package:flutter/material.dart';

import '../../../core/animation/animation_curves.dart';
import '../../../core/animation/animation_durations.dart';

/// Contextual page transitions so a new screen always feels like it grew
/// out of the previous one, rather than abruptly replacing it (product
/// spec §18).
abstract final class AppPageRoute {
  /// Fade + slight upward slide — used for most full-screen pushes
  /// (settings, route details).
  static Route<T> fadeSlide<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: AppDurations.pageTransition,
      reverseTransitionDuration: AppDurations.pageTransition,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppCurves.pageTransition);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Scale + fade from the tap origin — used for cards that "expand"
  /// into a detail screen (e.g. a search result -> place detail).
  static Route<T> scaleFade<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: AppDurations.modalTransition,
      reverseTransitionDuration: AppDurations.modalTransition,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppCurves.expand);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Slide up from the bottom, for screens that are conceptually a
  /// full-screen extension of a bottom sheet (e.g. AI navigation panel
  /// expanding to full screen).
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: AppDurations.navigationTransition,
      reverseTransitionDuration: AppDurations.modalTransition,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppCurves.sheetEnter);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }
}
