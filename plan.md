# Implementation Plan: Pure Native Kotlin Rewrite

## Goal
Transform Hashtype from a mixed Flutter + Kotlin architecture into a **100% pure native Android Kotlin application** powered by **Jetpack Compose (Material 3)**. Purge all legacy 24/7 floating mic mechanisms (dismiss targets, 15m/24h muting, auto-fold, game/landscape heuristics) and implement a lightweight, cursor-driven floating mic that only displays when an input field/cursor is active.

---

## 1. System Architecture

```
hashtype (Root Android Project)
├── app/
│   ├── src/main/
│   │   ├── AndroidManifest.xml
│   │   ├── kotlin/com/jia_yx/hashtype/
│   │   │   ├── MainActivity.kt                # Jetpack Compose UI Entrypoint
│   │   │   ├── ui/
│   │   │   │   ├── theme/
│   │   │   │   │   ├── Color.kt               # Fallback Blue Palette & Theme Colors
│   │   │   │   │   └── Theme.kt               # Material 3 DynamicColor Theme (Follows System)
│   │   │   │   ├── MainScreen.kt              # Bottom Navigation (Test, History, Settings)
│   │   │   │   ├── screens/
│   │   │   │   │   ├── TestScreen.kt          # Input testing field + permission status
│   │   │   │   │   ├── HistoryScreen.kt       # Transcription history list & search
│   │   │   │   │   ├── SettingsScreen.kt      # STT, LLM, Language, Floating Mic configs
│   │   │   │   │   ├── SttSettingsScreen.kt   # STT provider & API key settings
│   │   │   │   │   ├── LlmSettingsScreen.kt   # LLM cleanup prompt & model settings
│   │   │   │   │   ├── LanguageScreen.kt      # Speech recognition language picker
│   │   │   │   │   └── FloatingMicCustomizeScreen.kt # Floating mic size, icon, color customization
│   │   │   ├── services/
│   │   │   │   ├── HashtypeFloatingService.kt # Cursor-driven AccessibilityService
│   │   │   │   ├── VoiceInputMethodService.kt # Voice typing IME
│   │   │   │   ├── HashtypeRecognitionService.kt # System speech recognition bridge
│   │   │   │   ├── VoiceImeViewModel.kt       # Audio recording & STT/LLM pipeline
│   │   │   │   └── VoiceImeView.kt            # Native keyboard view
│   │   │   ├── data/
│   │   │   │   ├── AppSettings.kt             # Unified Kotlin SharedPreferences manager
│   │   │   │   ├── AiProviders.kt             # Unified STT & LLM provider configurations
│   │   │   │   └── HistoryDbHelper.kt         # SQLite transcription history
│   │   └── res/                               # Android drawables, icons, and XML configs
│   └── build.gradle.kts                       # Compose + Material 3 + OkHttp build script
├── build.gradle.kts                           # Root Gradle build script
├── settings.gradle.kts                        # Root Gradle settings script
└── gradle.properties                          # JVM & Android properties
```

---

## 2. Key Simplifications & Enhancements

### A. 100% Native Kotlin & Zero Flutter Bloat
- Completely delete `lib/`, `pubspec.yaml`, `pubspec.lock`, and Flutter Gradle plugins.
- Unified single source of truth for AI providers: no more duplicating logic across Dart and Kotlin.
- APK size drops from ~40MB to ~5MB; cold start becomes instantaneous.

### B. Material You Dynamic Color & System Theme
- Automatically follows Android 12+ wallpaper colors via `dynamicLightColorScheme(context)` and `dynamicDarkColorScheme(context)`.
- Fallback to clean standard blue (`Color(0xFF2196F3)`).
- Brightness strictly follows system settings (`isSystemInDarkTheme()`). No redundant appearance/dark mode settings.

### C. Cursor-Driven Floating Mic
- Floating mic enabled by default (`floating_mic_enabled = true`), with a toggle in Settings.
- Only displays when an editable text input field (`isEditable && isFocused`) is active.
- When focus is lost and state is `Idle`, automatically hides with a ~200ms debounce.
- While `Recording` or `Processing`, remains visible until transcription finishes and text is pasted.
- Simple single-tap to record / stop; drag smoothly repositions within screen bounds.
- Completely removed legacy code: no 15m/24h mute targets, no dismiss overlays, no border auto-fold, no landscape/game heuristics.

---

## 3. Step-by-Step Execution Plan

### Step 1: Migrate Android Project Structure to Root
- Move `android/app`, `android/build.gradle.kts`, `android/settings.gradle.kts`, `android/gradle.properties`, and `android/gradle` to the root of the repository.
- Remove Flutter files (`lib/`, `pubspec.yaml`, `pubspec.lock`, `.metadata`, `analysis_options.yaml`, `devtools_options.yaml`, and leftover `android/` directory).

### Step 2: Configure Pure Android Gradle Scripts with Jetpack Compose
- Update `settings.gradle.kts`:
  - Standard Android plugins repository management (`google()`, `mavenCentral()`).
  - Plugins: `com.android.application` (8.11.1), `org.jetbrains.kotlin.android` (2.2.20), `org.jetbrains.kotlin.plugin.compose` (2.2.20).
  - Include `:app`.
- Update `app/build.gradle.kts`:
  - Remove Flutter Gradle Plugin (`dev.flutter.flutter-gradle-plugin`).
  - Configure `compileSdk = 35`, `minSdk = 24`, `targetSdk = 35`.
  - Enable Compose: `buildFeatures { compose = true }`.
  - Add dependencies:
    - Compose BOM (`2024.09.00`)
    - `androidx.compose.ui:ui`, `androidx.compose.ui:ui-graphics`, `androidx.compose.ui:ui-tooling-preview`
    - `androidx.compose.material3:material3`
    - `androidx.compose.material:material-icons-extended`
    - `androidx.activity:activity-compose`
    - `androidx.lifecycle:lifecycle-viewmodel-compose`
    - `com.squareup.okhttp3:okhttp:4.12.0`
    - `com.google.android.material:material:1.12.0`

### Step 3: Refactor Core Data & Settings Layer
- Create `data/AppSettings.kt`:
  - Pure Kotlin singleton/helper managing SharedPreferences.
  - Manages STT settings, LLM settings, active languages, and floating mic styling (size, color, icon, enabled).
  - Defaults `floating_mic_enabled` to `true`.
- Create `data/AiProviders.kt`:
  - Complete list of supported STT and LLM providers: OpenAI, Groq, Anthropic, Google Gemini, Mistral, Deepgram, Custom.
  - Endpoint builders, model fetchers, and API key validation.

### Step 4: Overhaul `HashtypeFloatingService.kt`
- Remove all legacy code:
  - Delete `layout_dismiss_targets.xml`.
  - Remove dismiss overlays, 15m/24h muting, auto-fold, and orientation/game hiding.
  - Remove push-to-talk long-press handlers.
- Implement cursor-driven visibility:
  - Listen to `typeViewFocused|typeViewTextSelectionChanged|typeWindowStateChanged|typeWindowsChanged`.
  - Method `isInputActive(): Boolean` querying `rootInActiveWindow` and active windows for `findFocus(FOCUS_INPUT)`.
  - Debounced hide (~200ms) on focus lost when `Idle`.
  - Persistent visibility during `Recording` and `Processing`.
- Clean single-tap interaction and screen-clamped drag repositioning.

### Step 5: Implement Native Jetpack Compose UI
- Create `ui/theme/Theme.kt` and `ui/theme/Color.kt`:
  - Material 3 theme adapting to wallpaper via `dynamicLightColorScheme` / `dynamicDarkColorScheme`.
  - Default blue seed color fallback.
- Create `ui/MainScreen.kt`:
  - Material 3 NavigationBar with Test, History, and Settings tabs.
- Create `ui/screens/TestScreen.kt`:
  - Clean `OutlinedTextField` for instant floating mic testing.
  - Permission status banners (Microphone, Accessibility, Overlay).
- Create `ui/screens/HistoryScreen.kt`:
  - Transcription history list from `HistoryDbHelper`.
  - Search bar, item copy/delete, and clear-all.
- Create `ui/screens/SettingsScreen.kt`:
  - STT settings, LLM post-processing toggle & config, language picker.
  - Floating mic toggle switch, customize button, and auto-paste helper shortcut.
  - About dialog/card.
- Create sub-screens:
  - `SttSettingsScreen.kt` & `LlmSettingsScreen.kt` for configuring provider, API key, and model.
  - `FloatingMicCustomizeScreen.kt` with live interactive button preview, size selector, icon picker, and dynamic color toggle / vibrant presets.

### Step 6: Update `AGENTS.md` and Verify
- Update `AGENTS.md` to document the 100% pure Kotlin architecture.
- Verify compilation and file structure.
