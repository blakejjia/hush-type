# AGENTS.md — Hashtype (Voice-to-Text Assistant & IME)

## Project Overview

Hashtype is an Android speech-to-text input tool combining:
1. **Flutter Config App** (`lib/`): Manages STT/LLM provider keys, prompt customization, input languages, and floating mic appearance.
2. **Native Kotlin IME** (`VoiceInputMethodService.kt`): InputMethodService providing a voice-typing keyboard view.
3. **Native Kotlin Floating Mic** (`HashtypeFloatingService.kt`): AccessibilityService rendering a lightweight, cursor-driven floating microphone widget directly above any active text input on the system.
4. **Recognition Service** (`HashtypeRecognitionService.kt`): Standard Android speech recognition provider bridge.

- **Package name:** `com.jia_yx.hashtype` / `hashtype`
- **License:** GPL v3

---

## Build & Dev Commands

Run from the repository root:

| Command | Description |
|---|---|
| `flutter pub get` | Resolve dependencies |
| `flutter run` | Run debug app on connected device / emulator |
| `flutter analyze` | Static analysis (must pass with 0 warnings/errors) |
| `flutter build apk --debug` | Build debug APK |
| `flutter build apk --release` | Build release APK (`android/key.properties` needed) |

- Gradle wrapper: `8.14-all`, AGP `8.11.1`, Kotlin `2.2.20`, Java 17

---

## Critical Architecture: Dual Dart + Kotlin Implementation

AI provider settings logic exists in **two independent implementations** that must be kept in sync:

| Layer | Files |
|---|---|
| **Dart** (Flutter App) | `lib/services/ai_provider_registry.dart`, `lib/services/ai_feature_settings_service.dart` |
| **Kotlin** (IME & Floating Mic) | `android/.../ImeSettingsResolver.kt` |

Both read raw JSON from Android `SharedPreferences` (named `"FlutterSharedPreferences"`).

**Why:** Both `VoiceInputMethodService` and `HashtypeFloatingService` run natively in the background and can launch before the Flutter engine process is spun up. They cannot rely on Dart runtime state.

**Rule:** When adding/modifying an STT or LLM provider:
- Update Dart `AiProviderRegistry._providers` + endpoint builders.
- Update Kotlin `ImeSettingsResolver` `when` expressions + endpoint builders.

---

## Floating Mic Architecture (Cursor-Driven)

The floating microphone is implemented via `HashtypeFloatingService` (`AccessibilityService`) and is **cursor-driven**:

### 1. Visibility Lifecycle
- **Active Input**: Only shows when an editable text input field (`EditText`) has input focus (`FOCUS_INPUT`, `node.isEditable && node.isFocused`).
- **Focus Lost**: When the cursor/input field loses focus and the mic is in `Idle` state, the widget automatically hides with a ~200ms debounce to prevent flickering across window transitions.
- **Recording / Processing**: If the user is currently recording or transcribing, the mic stays visible regardless of focus changes until transcription finishes and text is pasted.
- **Default State**: Enabled by default (`flutter.floating_mic_enabled` defaults to `true`), with a toggle switch in the Settings page.

### 2. Interaction
- **Single Tap / Click**:
  - If `Idle`: starts recording.
  - If `Recording`: stops recording and initiates STT + LLM transcription pipeline.
- **Drag**: Smoothly repositions the floating mic across the screen, clamped within display bounds.
- **Auto-Paste**: Uses accessibility actions (`ACTION_PASTE`) and clipboard fallback to insert transcribed text at the active cursor.

### 3. Deliberately Omitted / Legacy Anti-Features
Do **NOT** re-introduce:
- ❌ 15-minute / 24-hour mute targets or dismiss overlays (now obsolete due to cursor-driven display).
- ❌ Border auto-fold animations.
- ❌ Landscape or gaming auto-hide detection heuristics.
- ❌ Push-to-talk long-press or long-press cancel.

---

## Theming & Styling

- **Dynamic Material You**: Uses `dynamic_color` with `DynamicColorBuilder`. Adapts to the user's Android 12+ wallpaper colors automatically.
- **Fallback**: Default blue palette (`Colors.blue`).
- **System Mode**: Brightness strictly follows `ThemeMode.system` (light when system is light, dark when system is dark).
- There are no manual "Appearance" or "Dark Mode" override switches in Settings.

---

## Shared Settings Schema (`FlutterSharedPreferences`)

| Key | Type | Description |
|---|---|---|
| `flutter.stt_settings` | String (JSON) | STT provider configuration, API key, endpoint, model |
| `flutter.llm_settings` | String (JSON) | LLM post-processing config, prompt, API key |
| `flutter.selected_languages` | List<String> | Active input language codes (e.g. `["en_US"]`) |
| `flutter.floating_mic_enabled` | Boolean | Global toggle for the floating mic (default: `true`) |
| `flutter.floating_mic_size` | String | Size preset: `"small"`, `"medium"`, `"large"` |
| `flutter.floating_mic_color` | String | Button color hex or `"theme"` for dynamic system color |
| `flutter.floating_mic_icon` | String | Icon name: `"mic"`, `"heart"`, `"star"`, `"chat"`, `"music"` |
| `flutter.floating_mic_icon_color` | String | Icon tint hex (default: `"#FFFFFF"`) |

---

## Android Service Manifest Structure

```
android/app/src/main/kotlin/com/jia_yx/hashtype/
├── MainActivity.kt               # Flutter engine host + MethodChannel bridge
├── VoiceInputMethodService.kt    # InputMethodService (IME keyboard)
├── VoiceImeViewModel.kt          # Shared state machine for audio recording, STT, LLM
├── VoiceImeView.kt               # Keyboard UI layout
├── HashtypeFloatingService.kt    # AccessibilityService for cursor-driven floating mic
├── HashtypeRecognitionService.kt # Android RecognitionService interface
├── ImeSettingsResolver.kt        # Kotlin settings deserializer
└── HistoryDbHelper.kt            # SQLite transcription history persistence
```

Two core permissions are critical for floating mic functionality:
- `android.permission.RECORD_AUDIO`: Voice input recording.
- `android.permission.BIND_ACCESSIBILITY_SERVICE`: Window inspection for cursor focus and text pasting.
