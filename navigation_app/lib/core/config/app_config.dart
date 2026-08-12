/// Centralized, build-time application configuration.
///
/// Values are injected at build time via `--dart-define` flags so that
/// no secret ever needs to be committed to source control. GitHub Actions
/// pulls these from repository Secrets (see `.github/workflows/*.yml`) and
/// forwards them to `flutter build` using this exact same variable naming.
///
/// Never hard-code API keys anywhere else in the codebase — always read
/// through [AppConfig].
class AppConfig {
  AppConfig._();

  /// Mapbox public/secret access token used for map tiles, geocoding,
  /// directions (routing), traffic and the Search Box (POI/parking) API.
  static const String mapApiKey = String.fromEnvironment('MAP_API_KEY');

  /// Geoapify API key used as a supplementary search/geocoding source
  /// alongside Mapbox (see [HybridSearchService]). Never used for map
  /// tiles, routing, or traffic — Mapbox remains the sole source there.
  static const String geoapifyApiKey =
      String.fromEnvironment('GEOAPIFY_API_KEY');

  /// Groq API key used for natural-language AI navigation commands.
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  /// Base URL for Mapbox's platform APIs.
  static const String mapboxBaseUrl = 'https://api.mapbox.com';

  /// Base URL for Geoapify's platform APIs.
  static const String geoapifyBaseUrl = 'https://api.geoapify.com';

  /// Base URL for the Groq OpenAI-compatible chat completions endpoint.
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';

  /// The Groq model used for structured AI navigation command parsing.
  ///
  /// Kept centralized so it can be changed in one place without touching
  /// business logic.
  static const String groqModel = 'llama-3.3-70b-versatile';

  /// Whether the app was built with all required keys present.
  ///
  /// The app must never crash on missing keys — features that depend on
  /// a missing key should degrade gracefully with a friendly message
  /// (see [lib/core/errors]).
  static bool get hasMapKey => mapApiKey.isNotEmpty;

  /// Whether Geoapify is configured. The hybrid search pipeline treats a
  /// missing Geoapify key the same as a Geoapify outage — it degrades
  /// gracefully to Mapbox-only results rather than failing the search.
  static bool get hasGeoapifyKey => geoapifyApiKey.isNotEmpty;

  static bool get hasGroqKey => groqApiKey.isNotEmpty;
}
