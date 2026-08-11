import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/core/errors/app_failure.dart';
import 'package:navigation_app/core/errors/result.dart';

void main() {
  group('Result', () {
    test('Ok exposes isOk/isErr correctly', () {
      const result = Result<int>.ok(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
    });

    test('Err exposes isOk/isErr correctly', () {
      const result = Result<int>.err(UnknownFailure());
      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
    });

    test('when() invokes the ok branch with the wrapped value', () {
      const result = Result<String>.ok('hello');
      final output = result.when(
        ok: (value) => 'ok:$value',
        err: (failure) => 'err:${failure.message}',
      );
      expect(output, 'ok:hello');
    });

    test('when() invokes the err branch with the wrapped failure', () {
      const result = Result<String>.err(NetworkFailure());
      final output = result.when(
        ok: (value) => 'ok:$value',
        err: (failure) => 'err:${failure.message}',
      );
      expect(output, contains('err:'));
    });
  });

  group('AppFailure', () {
    test('every failure exposes a non-empty, user-safe message', () {
      const failures = <AppFailure>[
        NetworkFailure(),
        LocationPermissionFailure(),
        LocationUnavailableFailure(),
        GeocodingFailure(),
        RoutingFailure(),
        TrafficFailure(),
        ParkingFailure(),
        AiNavigationFailure(),
        VoiceFailure(),
        ConfigurationFailure(),
        UnknownFailure(),
      ];

      for (final failure in failures) {
        expect(failure.message, isNotEmpty);
        // User-facing messages must never leak raw technical identifiers.
        expect(failure.message.toLowerCase(), isNot(contains('exception')));
        expect(failure.message.toLowerCase(), isNot(contains('socket')));
      }
    });

    test('technicalDetail is optional and kept separate from message', () {
      const failure = NetworkFailure(technicalDetail: 'SocketException: x');
      expect(failure.technicalDetail, contains('SocketException'));
      expect(failure.message, isNot(contains('SocketException')));
    });
  });
}
