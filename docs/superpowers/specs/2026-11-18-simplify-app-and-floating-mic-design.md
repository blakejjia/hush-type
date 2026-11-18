# Spec & Design: App Simplification and Floating Mic Cursor-Driven Overhaul

## 1. Context & Motivation
Hashtype is an Android voice typing keyboard and floating speech-to-text assistant. Previously, the floating mic attempted to remain on-screen 24/7, leading to excessive complexity:
- Draggable dismiss targets overlay to mute for 15 minutes or 24 hours.
- Edge auto-folding animations.
- Orientation-based and game-detection auto-hiding.
- Push-to-talk long-press vs. tap vs. long-press cancel.
- Redundant settings pages and toggles (Dark Mode switch, Theme Color palette picker, Enable Keyboard, Show Period Button).

This overhaul strips out all legacy hiding/muting code and simplifies the entire app experience:
1. Appearance follows the system mode automatically, with dynamic Material You colors (fallback to standard blue).
2. Keyboard settings section in Flutter UI is removed.
3. Floating Mic is enabled by default (`true`), but remains toggleable.
4. Floating Mic visibility is strictly **cursor-driven**: it only appears when the user is focusing an active text input field.
5. Floating Mic interaction is **single-tap to start, single-tap to stop & transcribe**.

---

## 2. Architecture & Design

### A. Theme & Appearance
- Dependency: Add `dynamic_color: ^1.7.0`.
- Behavior:
  - Root widget wrapped in `DynamicColorBuilder`.
  - Android 12+ system accent palette used via `lightDynamic` / `darkDynamic`.
  - Fallback: `ColorScheme.fromSeed(seedColor: Colors.blue)`.
  - `themeMode: ThemeMode.system` (automatic dark / light following Android system brightness).
  - Remove "Appearance" section from `settings_page.dart` and delete `theme_color_page.dart`.

### B. Settings Page Clean-up
- Remove "Appearance" section.
- Remove "Keyboard" section (Enable Keyboard & Show Period Button).
- Floating Voice Input section:
  - Default `floating_mic_enabled` to `true`.
  - Retain `Enable Floating Mic` toggle switch.
  - Retain `Auto-Paste Helper` (accessibility status & shortcut) and `Customize Floating Mic` (color/size/icon customization).
  - Delete `Auto Fold on Border`, `Hide in Landscape Mode`, `Hide in Games`.
  - Remove legacy SharedPreferences keys: `floating_mic_muted_until`, `floating_mic_auto_fold`, `floating_mic_hide_in_landscape`, `floating_mic_hide_in_games`.
  - Remove "Bring Back Muted Mic" card from `TestPage`.

### C. Floating Mic Cursor-Driven Lifecycle (`HashtypeFloatingService.kt`)
- `accessibility_service_config.xml`:
  - Listen for: `typeViewFocused|typeViewTextSelectionChanged|typeWindowStateChanged|typeWindowsChanged`.
  - Flags: `flagDefault|flagRetrieveInteractiveWindows`.
  - Enable `canRetrieveWindowContent="true"`.
- Focus Detection:
  - Active input field detection via `findFocus(AccessibilityNodeInfo.FOCUS_INPUT)` and checking `node.isEditable && node.isFocused`.
  - Debounce on hide (~200ms) to ensure smooth transitions between fields without screen flickering.
- State-Aware Visibility:
  - If input is active: show the floating mic.
  - If input is inactive AND `viewModel.getCurrentState() is ImeState.Idle`: hide the floating mic.
  - If `Recording` or `Processing`: keep floating mic visible until transcription finishes and text is pasted.
- Touch & Interaction:
  - Tap / Click: triggers `vibrate()` and `viewModel.handleMicClick()`.
    - If `Idle`: starts recording.
    - If `Recording`: stops recording and transcribes.
  - Drag: repositions the floating mic on screen (clamped to screen boundaries).
  - No dismiss targets overlay (delete `layout_dismiss_targets.xml`).
  - No auto-folding or muting.

---

## 3. AGENTS.md Rewrite
Update `AGENTS.md` at repository root to serve as an authoritative, comprehensive reference for future agents:
- Dual Dart + Kotlin architecture.
- AccessibilityService floating STT lifecycle and focus detection.
- Shared settings keys.
- Build & test commands.
