# AGENTS.md — Hashtype (Speech-to-Text IME)

## Project overview

Android voice-typing keyboard with Flutter config app + native Kotlin IME.
Single-package Flutter project rooted at the repo root.

- **Package name:** `com.jia_yx.hashtype` / `hashtype` (pub)
- **License:** GPL v3

## Build & dev commands

All run from the repo root:

| Command | Notes |
|---|---|
| `flutter pub get` | Install deps |
| `flutter run` | Launch on connected device/emulator |
| `flutter build apk --release` | Release APK (needs `key.properties` at android/ root) |
| `flutter build appbundle --release` | Play Store bundle |
| `flutter analyze` | Dart static analysis (flutter_lints defaults) |
| `flutter test` | Exists but **no tests written yet** |

- Gradle wrapper: `8.14-all`, AGP `8.11.1`, Kotlin `2.2.20`, Java 17
- JVM heap: 8 GB (`gradle.properties`)

## Critical architecture: dual Dart + Kotlin implementation

AI provider settings logic exists in **two independent implementations** that must be kept in sync:

| Layer | File |
|---|---|
| **Dart** (Flutter config app) | `lib/services/ai_provider_registry.dart` + `lib/services/ai_feature_settings_service.dart` |
| **Kotlin** (IME service) | `android/.../ImeSettingsResolver.kt` |

Both read the same raw JSON from `FlutterSharedPreferences` and independently compute runtime config (endpoints, auth headers, request types).

**Why:** The Kotlin `InputMethodService` can launch before the Flutter app process exists, so it cannot rely on Dart-computed caches.

**When you add/modify a provider, you MUST update both sides:**
- Dart: `AiProviderRegistry._providers` → `ProviderSpec` entries + `build*Endpoint()` static methods
- Kotlin: `ImeSettingsResolver` → `when` expressions, API key validators, `build*Endpoint()` methods

## Shared settings schema

Settings are stored in `SharedPreferences` (name: `"FlutterSharedPreferences"`) under these keys:

- `flutter.stt_settings` — STT provider config
- `flutter.llm_settings` — LLM provider config + system prompt
- `flutter.show_period_button` — keyboard toggle

Do not rename these keys or change the JSON structure without updating both Dart and Kotlin readers.

## IME vs App duality

- **Hashtype app** (Flutter): settings/config UI only. Does not type text.
- **Hashtype Keyboard** (Kotlin `VoiceInputMethodService`): the actual IME. Uses `VoiceImeViewModel` for recording, transcription, and LLM cleanup. Reads settings from `FlutterSharedPreferences`.

The keyboard can function independently once settings are saved by the app.

## Android module structure

```
android/app/src/main/kotlin/com/jia_yx/hashtype/
├── MainActivity.kt              # Flutter host, MethodChannel bridge
├── VoiceInputMethodService.kt   # IME entry point (InputMethodService)
├── VoiceImeViewModel.kt         # Recording, API calls, LLM pipeline
├── VoiceImeView.kt              # Keyboard UI layout
├── ImeSettingsResolver.kt       # Kotlin-side settings parsing
└── HashtypeRecognitionService.kt # Android RecognitionService bridge
```

Two services in `AndroidManifest.xml`: the IME service and the recognition service.

## Key dependencies

- `shared_preferences` — all settings persistence
- `http` — Flutter-side API calls
- `com.squareup.okhttp3:okhttp:4.12.0` — Kotlin-side HTTP
- UI: `google_fonts` (Outfit), Material 3 dynamic colors, `url_launcher`

## Style / conventions

- `analysis_options.yaml` inherits `package:flutter_lints/flutter.yaml` (defaults only, no custom rules)
- No `flutter_localizations` or `.arb` files — language is handled manually via `shared_preferences`
- No CI pipeline configured
