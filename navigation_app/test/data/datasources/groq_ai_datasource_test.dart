import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:navigation_app/core/errors/app_failure.dart';
import 'package:navigation_app/core/networking/api_client.dart';
import 'package:navigation_app/data/datasources/groq_ai_datasource.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('GroqAiDataSource.parseIntent', () {
    // Note: AppConfig.groqApiKey resolves to '' in the test environment
    // (no --dart-define is passed), so parseIntent short-circuits to
    // ConfigurationFailure before ever making an HTTP call. This mirrors
    // real behavior when the app is built/run without the key configured
    // and proves the feature degrades gracefully rather than crashing.
    test('returns ConfigurationFailure when no Groq key is configured',
        () async {
      final httpClient = _MockHttpClient();
      final dataSource =
          GroqAiDataSource(client: ApiClient(client: httpClient));

      final result = await dataSource.parseIntent('take me to the airport');

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected Err'),
        err: (failure) => expect(failure, isA<ConfigurationFailure>()),
      );
      // No network call should have been attempted at all.
      verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
    });
  });
}
