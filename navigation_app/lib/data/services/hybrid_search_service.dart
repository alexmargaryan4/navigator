import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/search_provider.dart';

/// Fans a free-text query out to every registered [SearchProvider] in
/// parallel (currently Mapbox and Geoapify — see product spec), then
/// merges, deduplicates, and ranks the combined results into a single
/// list the UI renders without ever knowing which provider a result
/// came from.
///
/// This is the one place that knows there is more than one search
/// backend. Everything above it (the repository, the controller, the
/// UI) only ever sees plain [Place] lists — adding a third provider
/// later means writing one more [SearchProvider] implementation and
/// adding it to [_providers]; nothing here or above changes.
///
/// Design choices driven directly by the product requirements:
///  - Providers are queried in parallel, never sequentially.
///  - If one provider fails or returns nothing, the other's results are
///    still returned — a total failure only happens if every provider
///    fails.
///  - Deduplication merges results that are almost certainly the same
///    real-world place (close coordinates + similar name) into one
///    entry, recording every provider that found it.
///  - Ranking never invents a synthetic relevance number for Geoapify.
///    It only uses signals every provider actually gives us: how well
///    the query text matches the name, category/completeness of the
///    result, proximity to the user, and whether more than one
///    provider agreed on the place.
class HybridSearchService {
  HybridSearchService({required List<SearchProvider> providers})
      : _providers = providers;

  final List<SearchProvider> _providers;

  /// Distance (meters) within which two results from different
  /// providers are considered the same real-world place, *provided*
  /// their names are also similar enough (see [_namesLikelyMatch]).
  /// Chosen to catch the same POI/address surviving small differences
  /// in each provider's geocoded point, while staying tight enough not
  /// to merge two distinct, nearby shops on the same street.
  static const double _dedupeDistanceMeters = 120;

  /// Runs [query] against every configured provider in parallel and
  /// returns a single merged, deduplicated, ranked list.
  ///
  /// Returns [Result.err] only when *every* provider fails — as long as
  /// at least one provider returns results (or a successful empty
  /// list), the search is considered to have succeeded so the app keeps
  /// working through a single-provider outage.
  Future<Result<List<Place>>> search(
    String query, {
    GeoPoint? proximity,
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const Result.ok(<Place>[]);
    }

    final responses = await Future.wait(
      _providers.map(
        (provider) => provider.search(trimmed, proximity: proximity, limit: limit),
      ),
    );

    final allPlaces = <Place>[];
    AppFailure? lastFailure;
    var anyOk = false;

    for (final response in responses) {
      response.when(
        ok: (places) {
          anyOk = true;
          allPlaces.addAll(places);
        },
        err: (failure) => lastFailure = failure,
      );
    }

    if (!anyOk) {
      return Result.err(lastFailure ?? const UnknownFailure());
    }

    final merged = _deduplicate(allPlaces);
    final ranked = _rank(merged, query: trimmed, proximity: proximity);
    return Result.ok(ranked.take(limit * _providers.length).toList());
  }

  /// Reverse-geocodes [point] using the first provider that succeeds,
  /// in registration order (Mapbox first). Reverse geocoding resolves a
  /// single coordinate to a single place, so there is nothing to merge
  /// — we only need one good answer, with the remaining providers as
  /// fallback if the preferred one is down.
  Future<Result<Place>> reverseGeocode(GeoPoint point) async {
    AppFailure? lastFailure;
    for (final provider in _providers) {
      final result = await provider.reverseGeocode(point);
      final place = result.when(ok: (p) => p, err: (f) {
        lastFailure = f;
        return null;
      });
      if (place != null) return Result.ok(place);
    }
    return Result.err(lastFailure ?? const UnknownFailure());
  }

  // ---------------------------------------------------------------------
  // Deduplication
  // ---------------------------------------------------------------------

  /// Merges results that different providers returned for the same
  /// real-world place. Two candidates are merged when they are within
  /// [_dedupeDistanceMeters] of each other AND their names are similar
  /// enough (see [_namesLikelyMatch]) — coordinates alone aren't
  /// sufficient (a mall and a shop inside it can share a point), and
  /// names alone aren't sufficient (two branches of the same chain in
  /// different cities share a name).
  ///
  /// Mapbox `/suggest` results that still need `/retrieve` (see
  /// [Place.needsCoordinateResolution]) carry a `(0, 0)` placeholder
  /// location and are therefore never merged with anything — merging on
  /// a placeholder coordinate would be meaningless. They pass through
  /// untouched and get resolved later, when the user actually picks one.
  List<Place> _deduplicate(List<Place> places) {
    final merged = <Place>[];

    for (final candidate in places) {
      if (candidate.needsCoordinateResolution) {
        merged.add(candidate);
        continue;
      }

      final matchIndex = merged.indexWhere((existing) {
        if (existing.needsCoordinateResolution) return false;
        final distance = existing.location.distanceTo(candidate.location);
        if (distance > _dedupeDistanceMeters) return false;
        return _namesLikelyMatch(existing.name, candidate.name);
      });

      if (matchIndex == -1) {
        merged.add(candidate);
        continue;
      }

      merged[matchIndex] = _combine(merged[matchIndex], candidate);
    }

    return merged;
  }

  /// Combines two candidates already established to be the same place,
  /// preferring whichever has richer data (a non-empty address wins,
  /// for instance) while recording both providers as matches — matching
  /// across providers is itself a strong relevance signal (see [_rank]).
  Place _combine(Place a, Place b) {
    final providers = <PlaceSource>{
      ...a.matchedProviders,
      if (a.source != null) a.source!,
      ...b.matchedProviders,
      if (b.source != null) b.source!,
    }.toList();

    final preferred = a.address.isNotEmpty ? a : (b.address.isNotEmpty ? b : a);

    return preferred.copyWith(matchedProviders: providers);
  }

  /// True when two place names are close enough to plausibly describe
  /// the same real-world object, allowing for the kind of small
  /// wording differences that are normal between two independent
  /// geocoders (e.g. transliteration, abbreviations, punctuation) —
  /// not an exact-string check.
  bool _namesLikelyMatch(String a, String b) {
    final normA = _normalize(a);
    final normB = _normalize(b);
    if (normA.isEmpty || normB.isEmpty) return false;
    if (normA == normB) return true;
    if (normA.contains(normB) || normB.contains(normA)) return true;
    return _similarity(normA, normB) >= 0.72;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Token-overlap similarity (Jaccard over word sets), in `[0, 1]`.
  /// Cheap, dependency-free, and adequate for short place names — a
  /// full edit-distance metric isn't needed for this call volume.
  double _similarity(String a, String b) {
    final tokensA = a.split(' ').toSet();
    final tokensB = b.split(' ').toSet();
    if (tokensA.isEmpty || tokensB.isEmpty) return 0;
    final intersection = tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;
    return union == 0 ? 0 : intersection / union;
  }

  // ---------------------------------------------------------------------
  // Ranking
  // ---------------------------------------------------------------------

  /// Scores and sorts [places] using only real, available signals —
  /// per the product requirement, Geoapify's lack of an explicit
  /// Mapbox-style relevance score is never papered over with a made-up
  /// number. Every signal below is derived from data the provider
  /// actually returned (or from the query/user location, which are
  /// facts we genuinely have):
  ///
  ///  - Text match: does the name start with / contain the query.
  ///  - Provider agreement: places more than one provider found for
  ///    the same query are almost certainly correct.
  ///  - Provider-native confidence: Geoapify's own `rank.confidence`
  ///    when present (see [Place.relevance] / `GeoapifyPlaceModel`),
  ///    used as-is rather than replaced with an invented figure.
  ///  - Completeness: results with a real address are preferred over
  ///    bare names.
  ///  - Proximity: closer to the user ranks higher, when we know where
  ///    the user is.
  List<Place> _rank(List<Place> places, {required String query, GeoPoint? proximity}) {
    final normalizedQuery = _normalize(query);

    final scored = places.map((place) {
      var score = 0.0;

      final normalizedName = _normalize(place.name);
      if (normalizedName == normalizedQuery) {
        score += 5.0;
      } else if (normalizedName.startsWith(normalizedQuery)) {
        score += 3.5;
      } else if (normalizedName.contains(normalizedQuery)) {
        score += 2.0;
      } else {
        // Partial token overlap still counts for something — e.g. the
        // query "Tumo" matching "TUMO Center for Creative Technologies".
        score += _similarity(normalizedName, normalizedQuery) * 2.0;
      }

      // Confirmed by more than one provider — the strongest real signal
      // we have that a result is genuinely the right place.
      if (place.matchedProviders.length > 1) {
        score += 2.5;
      }

      // Provider-native confidence (Geoapify's rank.confidence, when
      // present; defaults to a neutral 0.5 otherwise — see
      // GeoapifyPlaceModel). Never synthesized for providers that don't
      // supply it.
      score += place.relevance * 1.5;

      if (place.address.isNotEmpty) {
        score += 0.5;
      }

      if (proximity != null && !place.needsCoordinateResolution) {
        final distanceMeters = proximity.distanceTo(place.location);
        // Converts distance into a bounded, diminishing bonus rather
        // than a hard cutoff — a great text match a few km away should
        // still be able to outrank a poor match that happens to be
        // close, while very close results still get a meaningful nudge.
        final proximityBonus = 1.5 / (1 + distanceMeters / 2000);
        score += proximityBonus;
      }

      return place.copyWith(relevance: score);
    }).toList();

    scored.sort((a, b) => b.relevance.compareTo(a.relevance));
    return scored;
  }
}
