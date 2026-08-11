import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/ai_command.dart';
import '../../../domain/repositories/routing_repository.dart';
import '../../navigation/application/trip_controller.dart';

/// UI-facing phase of an AI navigation request.
enum AiRequestPhase { idle, thinking, resolving, done, needsClarification, failed }

class AiNavigationState {
  const AiNavigationState({
    this.phase = AiRequestPhase.idle,
    this.lastCommand,
    this.clarificationQuestion,
    this.failure,
  });

  final AiRequestPhase phase;
  final AiNavigationCommand? lastCommand;
  final String? clarificationQuestion;
  final AppFailure? failure;

  AiNavigationState copyWith({
    AiRequestPhase? phase,
    AiNavigationCommand? lastCommand,
    String? clarificationQuestion,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return AiNavigationState(
      phase: phase ?? this.phase,
      lastCommand: lastCommand ?? this.lastCommand,
      clarificationQuestion: clarificationQuestion ?? this.clarificationQuestion,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Bridges natural-language input to the real navigation pipeline
/// (spec §44-47): Groq only ever returns *intent*; this controller is
/// responsible for resolving that intent against real geocoding/routing
/// data before anything reaches the map.
class AiNavigationController extends AutoDisposeNotifier<AiNavigationState> {
  @override
  AiNavigationState build() => const AiNavigationState();

  Future<void> submit(String userText) async {
    if (userText.trim().isEmpty) return;

    state = state.copyWith(phase: AiRequestPhase.thinking, clearFailure: true);

    final aiService = ref.read(aiNavigationServiceProvider);
    final result = await aiService.interpret(userText);

    await result.when(
      ok: (command) => _handleCommand(command),
      err: (f) async => state = state.copyWith(phase: AiRequestPhase.failed, failure: f),
    );
  }

  Future<void> _handleCommand(AiNavigationCommand command) async {
    state = state.copyWith(lastCommand: command);

    switch (command.action) {
      case AiActionType.clarificationNeeded:
        state = state.copyWith(
          phase: AiRequestPhase.needsClarification,
          clarificationQuestion:
              command.clarificationQuestion ?? 'Could you clarify that?',
        );
        return;

      case AiActionType.unsupported:
        state = state.copyWith(
          phase: AiRequestPhase.failed,
          failure: const AiNavigationFailure(
            technicalDetail: 'unsupported action',
          ),
        );
        return;

      case AiActionType.calculateRoute:
        await _resolveAndRoute(command);
        return;

      case AiActionType.findParking:
        // Parking-specific resolution is handled by the parking feature;
        // this controller only marks the command resolved so the UI can
        // route the user to Parking with the destination query as a
        // search seed.
        state = state.copyWith(phase: AiRequestPhase.done);
        return;
    }
  }

  Future<void> _resolveAndRoute(AiNavigationCommand command) async {
    final query = command.destinationQuery;
    if (query == null) {
      state = state.copyWith(
        phase: AiRequestPhase.needsClarification,
        clarificationQuestion: 'Where would you like to go?',
      );
      return;
    }

    state = state.copyWith(phase: AiRequestPhase.resolving);

    final searchRepo = ref.read(searchRepositoryContractProvider);
    final placeResult = await searchRepo.resolveOne(query);

    await placeResult.when(
      ok: (place) async {
        final tripController = ref.read(tripControllerProvider.notifier);
        tripController.selectDestination(place);
        if (command.mode != null) {
          tripController.setMode(command.mode!);
        }
        tripController.setOptions(RouteOptions(
          avoidTolls: command.avoidTolls,
          avoidHighways: command.avoidHighways,
        ));
        await tripController.calculateRoutes();
        state = state.copyWith(phase: AiRequestPhase.done);
      },
      err: (f) async => state = state.copyWith(phase: AiRequestPhase.failed, failure: f),
    );
  }

  void reset() => state = const AiNavigationState();
}

final aiNavigationControllerProvider =
    AutoDisposeNotifierProvider<AiNavigationController, AiNavigationState>(
  AiNavigationController.new,
);
