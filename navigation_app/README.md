# Navigator

A modern, AI-powered navigation app built with Flutter — real maps, real
routing, real traffic, real parking data, and natural-language AI
navigation commands. No fabricated data, no custom backend.

This project is designed to be developed, built, and shipped **entirely
from a smartphone**, using GitHub and GitHub Actions. No PC, no Mac, no
local Flutter SDK, no Android Studio, no Xcode required.

---

## Repository structure

```
repository-root/
├── .github/workflows/
│   ├── build-android.yml   # builds the release APK
│   └── build-ios.yml       # builds the unsigned IPA
└── navigation_app/         # the actual Flutter project
    ├── android/
    ├── ios/
    ├── lib/
    ├── test/
    ├── assets/
    ├── pubspec.yaml
    ├── analysis_options.yaml
    └── README.md            # (this file)
```

The Flutter project lives inside `navigation_app/`, not at the repository
root. All `flutter` CLI commands in CI run from that directory.

## Architecture

```
lib/
  app/            App shell, Riverpod providers, wiring
  core/           config, theme, networking, permissions, location,
                  errors, animation/motion tokens
  data/           models, datasources (talk to external APIs), repository
                  implementations
  domain/         entities, repository interfaces, use cases
  features/       map, search, navigation, traffic, parking,
                  ai_navigation, settings — each split into
                  application/ (controllers/state) and presentation/ (UI)
  services/       routing, geocoding, traffic, parking, ai, voice
  shared/         reusable widgets (buttons, glass, loading, motion)
```

Clean Architecture + Riverpod. UI never talks to an external API directly
— it goes through a controller → repository → datasource chain, so the
map/routing/traffic/parking provider can be swapped without touching any
widget.

There is **no backend server**. The Flutter app talks directly to:

```
Flutter App
    ├── Mapbox      (map tiles, geocoding, routing, traffic, search/POI/parking)
    └── Groq        (natural-language AI navigation commands)
```

## Map, routing, traffic & parking provider — Mapbox

Mapbox was selected because a single account/token covers vector map
tiles, geocoding, turn-by-turn directions with live traffic, and POI
search (including parking), with solid Flutter support via `maplibre_gl`
(MapLibre's renderer is Mapbox Style Spec-compatible, so it can consume a
standard Mapbox style URL).

- **Maps**: Mapbox vector tiles / Styles API — modern vector rendering,
  worldwide coverage, light/dark styles.
- **Geocoding & search**: Mapbox Search Box API.
- **Routing**: Mapbox Directions API (`driving-traffic`, `walking`,
  `cycling` profiles). Alternatives, toll/highway avoidance, and
  congestion annotations are requested on the driving-traffic profile.
- **Traffic**: live congestion annotations returned by the
  `driving-traffic` Directions profile — no separate traffic call.
- **Parking**: Mapbox Search Box category search, filtered to parking
  POIs.

**Free tier limitation**: Mapbox's free tier is generous but capped
(monthly request quotas per API). It is **not unlimited**. For personal
use, testing, and prototyping this is fine; a production/commercial
release should plan around Mapbox's published pricing and rate limits,
and revisit whether request volume needs a paid tier. Attribution is
required and is shown on the map per Mapbox's terms.

## AI navigation — Groq

The AI navigation feature (`lib/services/ai/ai_navigation_service.dart`)
sends the user's typed or spoken sentence to Groq's OpenAI-compatible
chat completions endpoint and asks it to return a **structured JSON
command** (destination, travel mode, arrival time, preferences like
"avoid tolls"), never raw coordinates, routes, ETAs, or traffic — those
always come from Mapbox:

```
User → Groq (parses intent) → structured command → Flutter validates it
     → real Mapbox API call → real result → map
```

Flutter validates every structured response before acting on it. The AI
never executes arbitrary code and never invents navigation data.

## Motion / animation system

Centralized in `lib/core/animation/`:

- `animation_durations.dart`, `animation_curves.dart`, `motion_tokens.dart`
  — shared duration/curve constants so no widget hand-rolls its own
  timing.
- `lib/shared/widgets/motion/` — reusable animation primitives
  (`staggered_fade_in.dart`, `animated_counter.dart`).
- `lib/shared/widgets/buttons/pressable.dart` — the standard
  press-feedback wrapper (scale/opacity) used by every interactive
  element.
- `lib/shared/widgets/glass/glass_surface.dart` — the shared Liquid
  Glass surface used by sheets, cards, and panels.
- `lib/shared/widgets/navigation/app_page_route.dart` — custom page
  transitions (fade/slide/scale) instead of default Material routes.

## API keys — configuration

Keys are never hard-coded. They're centralized in
`lib/core/config/app_config.dart` and read at build time via
`String.fromEnvironment`, populated with `--dart-define`:

```
MAP_API_KEY   → Mapbox access token
GROQ_API_KEY  → Groq API key
```

No `.env` file is used or committed. No real key is committed anywhere
in this repository.

### Security note

Because this app intentionally has no backend, keys baked into the
compiled app via `--dart-define` can potentially be extracted from the
APK/IPA. That's an accepted tradeoff for development, personal use,
testing, and controlled distribution. A future public/commercial release
should introduce a proper backend/key-broker instead of shipping keys in
the client — that is explicitly out of scope for this project right now.

## GitHub Secrets setup

On the phone, in the GitHub app or mobile browser:

**Repo → Settings → Secrets and variables → Actions → New repository secret**

Add:

- `MAP_API_KEY` — your Mapbox access token
- `GROQ_API_KEY` — your Groq API key

Both workflows read these via `${{ secrets.MAP_API_KEY }}` /
`${{ secrets.GROQ_API_KEY }}` and forward them to `flutter build` with
`--dart-define`.

## Building from your phone

You never run `flutter build` locally — GitHub Actions does it.

### Android

1. Push a commit to `main` (or run the workflow manually: repo →
   **Actions** → **Build Android** → **Run workflow**).
2. Wait for the `Build Android` workflow to go green.
3. Open the finished run → **Artifacts** → download
   `navigation-android-release` (contains
   `navigation-android-release.apk`).
4. On Android, open the downloaded APK to install it (allow installs
   from your browser/files app if prompted). This is a real `--release`
   build, not debug.

### iOS

1. Same push, or run **Build iOS** manually from the **Actions** tab.
2. Wait for the `Build iOS` workflow (runs on a macOS runner) to finish.
3. Download the `navigation-ios-unsigned` artifact → contains
   `navigation-ios-unsigned.ipa`.
4. This IPA is **intentionally unsigned** — no Apple certificates,
   provisioning profiles, or App Store Connect are involved in CI at
   all. Sign it yourself using **ESign** (or a similar on-device signer)
   before installing it on an iPhone/iPad.

Both workflows run `flutter analyze` and `flutter test` before building;
if either fails, the build step doesn't run.

## Scope

In scope: maps, GPS, search, geocoding, driving/walking/cycling routing,
traffic, parking, AI navigation, voice search, voice navigation, speed
and road info where the provider supplies it.

Out of scope (not implemented): taxi/ride-hailing, buses, metro,
trolleybuses, or any public-transit features.
