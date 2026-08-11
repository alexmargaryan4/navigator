import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:navigation_app/core/errors/app_failure.dart';
import 'package:navigation_app/core/errors/result.dart';
import 'package:navigation_app/data/datasources/groq_ai_datasource.dart';
import 'package:navigation_app/domain/entities/ai_command.dart';
import 'package:navigation_app/domain/entities/travel_mode.dart';
import 'package:navigation_app/services/ai/ai_navigation_service.dart';

class _MockGroqAiDataSource extends Mock implements GroqAiDataSource {}

void main() {
  late _MockGroqAiDataSource dataSource;
  late AiNavigationService service;

  setUp(() {
    dataSource = _MockGroqAiDataSource();
    service = AiNavigationService(dataSource: dataSource);
  });

  Future<Result<AiNavigationCommand>> interpretWith(
      Map<String, dynamic> json) {
    when(() => dataSource.parseIntent(any()))
        .thenAnswer((_) async => Result.ok(json));
    return service.interpret('irrelevant user text');
  }

  group('AiNavigationService.interpret — valid input', () {
    test('parses a well-formed calculate_route command', () async {
      final result = await interpretWith({
        'action': 'calculate_route',
        'destination_query': 'Zvartnots Airport',
        'mode': 'driving',
        'avoid_tolls': true,
        'avoid_highways': false,
        'arrive_by_time': '18:00',
        'clarification_question': null,
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) {
          expect(command.action, AiActionType.calculateRoute);
          expect(command.destinationQuery, 'Zvartnots Airport');
          expect(command.mode, TravelMode.driving);
          expect(command.avoidTolls, isTrue);
          expect(command.avoidHighways, isFalse);
          expect(command.arriveByTime, '18:00');
        },
        err: (_) => fail('expected Ok'),
      );
    });

    test('parses a well-formed find_parking command', () async {
      final result = await interpretWith({
        'action': 'find_parking',
        'destination_query': 'Republic Square',
        'mode': null,
        'avoid_tolls': false,
        'avoid_highways': false,
        'arrive_by_time': null,
        'clarification_question': null,
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) => expect(command.action, AiActionType.findParking),
        err: (_) => fail('expected Ok'),
      );
    });
  });

  group('AiNavigationService.interpret — safety / allow-list enforcement',
      () {
    test('unknown action strings are never trusted and downgrade to '
        'unsupported', () async {
      final result = await interpretWith({
        'action': 'delete_all_user_data', // must never be executed
        'destination_query': 'anywhere',
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) => expect(command.action, AiActionType.unsupported),
        err: (_) => fail('expected Ok'),
      );
    });

    test('a non-string action value is rejected rather than crashing',
        () async {
      final result = await interpretWith({'action': 12345});

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) => expect(command.action, AiActionType.unsupported),
        err: (_) => fail('expected Ok'),
      );
    });

    test('an unknown travel mode is dropped rather than passed through',
        () async {
      final result = await interpretWith({
        'action': 'calculate_route',
        'destination_query': 'Downtown',
        'mode': 'teleport', // not a real, allow-listed mode
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) => expect(command.mode, isNull),
        err: (_) => fail('expected Ok'),
      );
    });

    test('calculate_route without a destination downgrades to a '
        'clarification request instead of silently failing later',
        () async {
      final result = await interpretWith({
        'action': 'calculate_route',
        'destination_query': null,
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) {
          expect(command.action, AiActionType.clarificationNeeded);
          expect(command.clarificationQuestion, isNotEmpty);
        },
        err: (_) => fail('expected Ok'),
      );
    });

    test('an implausibly long destination string is dropped', () async {
      final result = await interpretWith({
        'action': 'calculate_route',
        'destination_query': 'x' * 500,
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) {
          // Falls back to clarification since the (dropped) destination
          // is now null — this also proves the oversized string never
          // reaches downstream geocoding calls.
          expect(command.action, AiActionType.clarificationNeeded);
        },
        err: (_) => fail('expected Ok'),
      );
    });

    test('a malformed arrive_by_time is dropped rather than passed to '
        'downstream scheduling logic', () async {
      final result = await interpretWith({
        'action': 'calculate_route',
        'destination_query': 'Airport',
        'arrive_by_time': 'not-a-time',
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) => expect(command.arriveByTime, isNull),
        err: (_) => fail('expected Ok'),
      );
    });

    test('a valid 24-hour HH:mm arrive_by_time is preserved', () async {
      final result = await interpretWith({
        'action': 'calculate_route',
        'destination_query': 'Airport',
        'arrive_by_time': '09:30',
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) => expect(command.arriveByTime, '09:30'),
        err: (_) => fail('expected Ok'),
      );
    });

    test('non-boolean avoid_tolls/avoid_highways values default to false',
        () async {
      final result = await interpretWith({
        'action': 'calculate_route',
        'destination_query': 'Airport',
        'avoid_tolls': 'yes', // not a real boolean
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (command) => expect(command.avoidTolls, isFalse),
        err: (_) => fail('expected Ok'),
      );
    });
  });

  group('AiNavigationService.interpret — upstream failure propagation', () {
    test('propagates a failure from the data source unchanged', () async {
      when(() => dataSource.parseIntent(any()))
          .thenAnswer((_) async => const Result.err(AiNavigationFailure()));

      final result = await service.interpret('take me home');

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected Err'),
        err: (failure) => expect(failure, isA<AiNavigationFailure>()),
      );
    });
  });
}
