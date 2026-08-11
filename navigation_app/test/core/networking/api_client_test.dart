import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:navigation_app/core/errors/app_failure.dart';
import 'package:navigation_app/core/networking/api_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  late _MockHttpClient httpClient;
  late ApiClient apiClient;

  setUp(() {
    httpClient = _MockHttpClient();
    apiClient = ApiClient(client: httpClient);
  });

  group('ApiClient.getJson', () {
    test('returns Ok with the decoded body on a 200 response', () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({'foo': 'bar'}),
                200,
              ));

      final result = await apiClient.getJson(Uri.parse('https://example.com'));

      expect(result.isOk, isTrue);
      result.when(
        ok: (json) => expect(json['foo'], 'bar'),
        err: (_) => fail('expected Ok'),
      );
    });

    test('wraps a bare JSON list under a "data" key', () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(jsonEncode([1, 2, 3]), 200));

      final result = await apiClient.getJson(Uri.parse('https://example.com'));

      expect(result.isOk, isTrue);
      result.when(
        ok: (json) => expect(json['data'], [1, 2, 3]),
        err: (_) => fail('expected Ok'),
      );
    });

    test('returns NetworkFailure on a non-2xx status code', () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Server error', 500));

      final result = await apiClient.getJson(Uri.parse('https://example.com'));

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected Err'),
        err: (failure) => expect(failure, isA<NetworkFailure>()),
      );
    });

    test('returns NetworkFailure when the socket connection fails',
        () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(const SocketException('Failed host lookup'));

      final result = await apiClient.getJson(Uri.parse('https://example.com'));

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected Err'),
        err: (failure) {
          expect(failure, isA<NetworkFailure>());
          // The friendly message must never leak the raw exception type.
          expect(failure.message, isNot(contains('SocketException')));
        },
      );
    });

    test('returns UnknownFailure rather than crashing on malformed JSON',
        () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{not valid json', 200));

      final result = await apiClient.getJson(Uri.parse('https://example.com'));

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected Err'),
        err: (failure) => expect(failure, isA<UnknownFailure>()),
      );
    });
  });

  group('ApiClient.postJson', () {
    test('sends a JSON-encoded body and returns the decoded response',
        () async {
      when(() => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'ok': true}),
            200,
          ));

      final result = await apiClient.postJson(
        Uri.parse('https://example.com'),
        body: {'hello': 'world'},
      );

      expect(result.isOk, isTrue);
      final captured = verify(() => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured.single as String;
      expect(jsonDecode(captured), {'hello': 'world'});
    });
  });
}
