import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/place.dart';

/// The search screen's full state — query text, in-flight/loaded
/// results, and any surfaced failure.
class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.failure,
  });

  final String query;
  final List<Place> results;
  final bool isLoading;
  final AppFailure? failure;

  SearchState copyWith({
    String? query,
    List<Place>? results,
    bool? isLoading,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Debounces free-text input and drives [SearchRepository.search].
///
/// A short debounce (spec-appropriate for autocomplete: fast enough to
/// feel live, long enough not to spam the provider on every keystroke)
/// keeps the UI feeling instant without over-calling the API.
class SearchController extends AutoDisposeNotifier<SearchState> {
  Timer? _debounce;
  int _requestId = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void onQueryChanged(String query, {GeoPoint? proximity}) {
    _debounce?.cancel();
    state = state.copyWith(query: query, clearFailure: true);

    if (query.trim().isEmpty) {
      state = state.copyWith(results: const [], isLoading: false);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 260), () {
      _runSearch(query, proximity: proximity);
    });
  }

  Future<void> _runSearch(String query, {GeoPoint? proximity}) async {
    final thisRequest = ++_requestId;
    state = state.copyWith(isLoading: true, clearFailure: true);

    final repo = ref.read(searchRepositoryContractProvider);
    final result = await repo.search(query, proximity: proximity);

    // A newer keystroke started another request while this one was in
    // flight — drop this stale response rather than flashing outdated
    // results back onto the screen.
    if (thisRequest != _requestId) return;

    result.when(
      ok: (places) => state = state.copyWith(results: places, isLoading: false),
      err: (f) => state = state.copyWith(isLoading: false, failure: f, results: const []),
    );
  }

  void clear() {
    _debounce?.cancel();
    state = const SearchState();
  }
}

final searchControllerProvider =
    AutoDisposeNotifierProvider<SearchController, SearchState>(SearchController.new);
