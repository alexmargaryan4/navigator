import 'dart:ui' show PlatformDispatcher;

/// Resolves the app's display name (and the splash screen's tagline)
/// from the device's system language.
///
/// This mirrors the native launcher name set per-locale on each
/// platform (Android `values-ru`/`values-hy`/`values`, iOS
/// `ru.lproj`/`hy.lproj`/`en.lproj` `InfoPlist.strings`), so the name
/// shown inside the Flutter UI (splash screen, [MaterialApp.title])
/// always agrees with what the OS shows on the home screen icon:
/// - Russian device language → "НавИИ"
/// - Armenian device language → "ՆավԱԲ"
/// - anything else → "NavAI" (English)
///
/// This is intentionally a standalone, tiny resolver rather than the
/// app's full interface localization (translating every screen) —
/// that is handled separately. It only decides the app name/tagline.
class AppName {
  AppName._();

  static const String _ruLanguageCode = 'ru';
  static const String _hyLanguageCode = 'hy';

  /// The device's current language code (e.g. `en`, `ru`, `hy`), read
  /// directly from the platform rather than from [MaterialApp]'s
  /// resolved locale, so this works even before any `Localizations`
  /// widget exists in the tree (the splash screen renders first).
  static String get _deviceLanguageCode =>
      PlatformDispatcher.instance.locale.languageCode.toLowerCase();

  /// The localized app display name for the current device language.
  static String get displayName {
    switch (_deviceLanguageCode) {
      case _ruLanguageCode:
        return 'НавИИ';
      case _hyLanguageCode:
        return 'ՆավԱԲ';
      default:
        return 'NavAI';
    }
  }

  /// The splash screen's tagline, localized alongside [displayName].
  static String get tagline {
    switch (_deviceLanguageCode) {
      case _ruLanguageCode:
        return 'Куда бы вы ни направлялись';
      case _hyLanguageCode:
        return 'Ուր էլ որ գնաս';
      default:
        return "Wherever you're headed";
    }
  }
}
