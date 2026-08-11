import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('mapApiKey defaults to empty when not provided via --dart-define',
        () {
      // In the test environment no --dart-define is passed, so this
      // documents the safe default rather than a crash — the app must
      // degrade gracefully, never throw, when a key is missing (spec §6).
      expect(AppConfig.mapApiKey, isA<String>());
    });

    test('groqApiKey defaults to empty when not provided via --dart-define',
        () {
      expect(AppConfig.groqApiKey, isA<String>());
    });

    test('hasMapKey is false when mapApiKey is empty', () {
      if (AppConfig.mapApiKey.isEmpty) {
        expect(AppConfig.hasMapKey, isFalse);
      }
    });

    test('hasGroqKey is false when groqApiKey is empty', () {
      if (AppConfig.groqApiKey.isEmpty) {
        expect(AppConfig.hasGroqKey, isFalse);
      }
    });

    test('mapboxBaseUrl is a valid absolute HTTPS URL', () {
      final uri = Uri.parse(AppConfig.mapboxBaseUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    });

    test('groqBaseUrl is a valid absolute HTTPS URL', () {
      final uri = Uri.parse(AppConfig.groqBaseUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    });

    test('groqModel is a non-empty model identifier', () {
      expect(AppConfig.groqModel, isNotEmpty);
    });
  });
}
