import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers/theme_mode_provider.dart';
import '../../../core/animation/motion_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/buttons/pressable.dart';
import '../../../shared/widgets/glass/glass_surface.dart';

/// Persists the user's [ThemeMode] choice locally.
///
/// Kept private to the settings feature (per the doc comment on
/// [ThemeModeNotifier]) so the rest of the app depends only on the
/// in-memory [themeModeProvider] and never needs to know persistence
/// exists at all.
class _ThemePrefs {
  static const _key = 'theme_mode';

  static Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  static Future<ThemeMode?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return ThemeMode.values.where((m) => m.name == raw).firstOrNull;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Settings screen (product spec §53): theme selection plus a short,
/// honest account of which real providers power the app — no invented
/// "premium" claims, just what's actually wired up.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _restoreSavedTheme();
  }

  Future<void> _restoreSavedTheme() async {
    final saved = await _ThemePrefs.load();
    if (saved != null && mounted) {
      ref.read(themeModeProvider.notifier).setMode(saved);
    }
  }

  void _setMode(ThemeMode mode) {
    ref.read(themeModeProvider.notifier).setMode(mode);
    _ThemePrefs.save(mode);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    final motion = MotionTokens.current();
    final currentMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                AppIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel('Appearance'),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: motion.cardTransition.duration,
              curve: motion.cardTransition.curve,
              child: GlassSurface(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: ThemeMode.values.map((mode) {
                    final isSelected = mode == currentMode;
                    return Pressable(
                      onTap: () => _setMode(mode),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient:
                              isSelected ? AppGradients.brandSubtle(colors) : null,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? colors.accent.withOpacity(0.3)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              switch (mode) {
                                ThemeMode.light => Icons.light_mode_rounded,
                                ThemeMode.dark => Icons.dark_mode_rounded,
                                ThemeMode.system =>
                                  Icons.brightness_auto_rounded,
                              },
                              size: 20,
                              color:
                                  isSelected ? colors.accent : colors.onSurfaceMuted,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              switch (mode) {
                                ThemeMode.light => 'Light',
                                ThemeMode.dark => 'Dark',
                                ThemeMode.system => 'System',
                              },
                              style: TextStyle(
                                color: isSelected
                                    ? colors.onSurface
                                    : colors.onSurfaceMuted,
                                fontSize: 15,
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check_rounded,
                                  color: colors.accent, size: 18),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel('About'),
            const SizedBox(height: 10),
            GlassSurface(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Maps & routing', value: 'Mapbox'),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'AI navigation', value: 'Groq'),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Voice', value: 'On-device speech & TTS'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Map data, routing, traffic, and parking results come from '
                'Mapbox. AI understanding of natural-language requests is '
                'provided by Groq. Nothing here is fabricated locally — if '
                'a provider doesn\'t return a piece of information, the '
                'app shows it as unavailable rather than guessing.',
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12.5, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: colors.onSurfaceMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors;
    return Row(
      children: [
        Text(label, style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
