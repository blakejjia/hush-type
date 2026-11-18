# AGENTS.md — Hashtype (100% Native Kotlin Voice Assistant & IME)

## Project Overview

Hashtype is a **100% pure native Android** speech-to-text input tool built in Kotlin with **Jetpack Compose (Material 3)**. It combines:
1. **Native Jetpack Compose App** (`app/src/main/kotlin/com/jia_yx/hashtype/ui/`): Modern Material 3 interface with dynamic theming for managing STT & LLM keys, input languages, transcription history, and floating mic customization.
2. **Native Kotlin IME** (`VoiceInputMethodService.kt`): InputMethodService providing a voice-typing keyboard view.
3. **Native Kotlin Floating Mic** (`HashtypeFloatingService.kt`): AccessibilityService rendering a lightweight, cursor-driven floating microphone widget directly above any active text input field on the system.
4. **Recognition Service** (`HashtypeRecognitionService.kt`): Android SpeechRecognizer interface bridge.
5. **Local SQLite History** (`HistoryDbHelper.kt`): Persistent transcription logs with search and cleanup capabilities.

- **Package name:** `com.jia_yx.hashtype`
- **License:** GPL v3
- **Tech Stack:** Android Native Kotlin 2.2.20, Jetpack Compose Material 3, OkHttp 4.12.0, AGP 8.11.1, Java 17

---

## Build & Dev Commands

Run from the repository root:

| Command | Description |
|---|---|
| `./gradlew assembleDebug` (or Android Studio Build) | Build debug APK |
| `./gradlew assembleRelease` | Build release APK (`key.properties` needed) |
| `./gradlew test` | Run unit tests |

---

## Architecture: Pure Kotlin (Single Source of Truth)

Previously, AI provider settings and logic were duplicated across Flutter Dart and Kotlin. In this modern pure Kotlin architecture:
- **`data/AppSettings.kt`**: Central repository managing SharedPreferences (`"FlutterSharedPreferences"` for backward compatibility).
- **`data/AiProviders.kt`**: Single source of truth for STT and LLM provider specifications (OpenAI, Groq, Anthropic, Google Gemini, Mistral, Deepgram, Custom), endpoint resolution, and API key validation.
- **`ImeSettingsResolver.kt`**: Deserializes SharedPreferences JSON for background services (`VoiceInputMethodService` and `HashtypeFloatingService`).

---

## Floating Mic Architecture (Keyboard-Driven)

The floating microphone is implemented via `HashtypeFloatingService` (`AccessibilityService`) and is **strictly keyboard-driven**:

### 1. Visibility Lifecycle
- **Keyboard Opened**: Only shows when the soft keyboard (`AccessibilityWindowInfo.TYPE_INPUT_METHOD`) pops up and is active on screen.
- **Keyboard Dismissed**: When the user dismisses the keyboard (swipes down, presses Back, or taps outside), the widget automatically hides with a ~100ms debounce.
- **Recording / Processing**: If the user is currently recording or transcribing, the mic stays visible regardless of keyboard changes until transcription finishes and text is pasted.
- **Position Memory**: Dragged position is remembered across show/hide cycles.
- **Default State**: Enabled by default (`flutter.floating_mic_enabled` defaults to `true`), with a toggle switch in the Settings screen.

### 2. Interaction
- **Single Tap / Click**:
  - If `Idle`: starts recording.
  - If `Recording`: stops recording and initiates STT + LLM transcription pipeline.
- **Drag**: Smoothly repositions the floating mic across the screen, clamped within display bounds.
- **Auto-Paste**: Uses accessibility actions (`ACTION_PASTE`) and clipboard fallback to insert transcribed text at the active cursor.

### 3. Deliberately Omitted / Legacy Anti-Features
Do **NOT** re-introduce:
- ❌ 15-minute / 24-hour mute targets or dismiss overlays (obsolete due to cursor-driven display).
- ❌ Border auto-fold animations.
- ❌ Landscape or gaming auto-hide detection heuristics.
- ❌ Push-to-talk long-press or long-press cancel.

---

## Theming & Styling

- **Dynamic Material You**: Uses `dynamicLightColorScheme(context)` and `dynamicDarkColorScheme(context)`. Adapts to the user's Android 12+ wallpaper colors automatically.
- **Fallback**: Clean blue palette (`Color(0xFF1976D2)`).
- **System Mode**: Brightness strictly follows `isSystemInDarkTheme()` (light when system is light, dark when system is dark).
- There are no manual "Appearance" or "Dark Mode" override switches.

---

## Directory Structure

```
hashtype/
├── app/
│   ├── src/main/
│   │   ├── AndroidManifest.xml
│   │   ├── kotlin/com/jia_yx/hashtype/
│   │   │   ├── HashtypeApp.kt               # Application entrypoint (DynamicColors)
│   │   │   ├── MainActivity.kt              # Compose ComponentActivity
│   │   │   ├── VoiceInputMethodService.kt   # IME Service
│   │   │   ├── VoiceImeViewModel.kt         # State machine & HTTP audio pipeline
│   │   │   ├── VoiceImeView.kt              # IME keyboard layout
│   │   │   ├── HashtypeFloatingService.kt   # Cursor-driven floating mic
│   │   │   ├── HashtypeRecognitionService.kt# SpeechRecognizer service
│   │   │   ├── HistoryDbHelper.kt           # SQLite transcription history
│   │   │   ├── ImeSettingsResolver.kt       # Settings deserializer
│   │   │   ├── data/
│   │   │   │   ├── AppSettings.kt           # SharedPreferences data manager
│   │   │   │   └── AiProviders.kt           # AI provider registry & endpoints
│   │   │   └── ui/
│   │   │       ├── MainScreen.kt            # Bottom navigation (Test, History, Settings)
│   │   │       ├── theme/
│   │   │       │   ├── Color.kt             # Color palette
│   │   │       │   └── Theme.kt             # Material 3 Theme with DynamicColors
│   │   │       └── screens/
│   │   │           ├── TestScreen.kt        # Interactive text field & permission checks
│   │   │           ├── HistoryScreen.kt     # SQLite history list, search & copy
│   │   │           ├── SettingsScreen.kt    # Main settings menu
│   │   │           ├── SttSettingsDialog.kt # STT provider & API key config
│   │   │           ├── LlmSettingsDialog.kt # LLM prompt & model config
│   │   │           ├── LanguageSelectionDialog.kt # Language picker
│   │   │           └── FloatingMicCustomizeDialog.kt # Mic size, icon & color preview
│   │   └── res/                             # Icons, drawables & service XMLs
│   └── build.gradle.kts                     # App module Gradle configuration
├── build.gradle.kts                         # Root Gradle script
├── settings.gradle.kts                      # Root Gradle settings
└── plan.md                                  # Complete implementation plan
```
