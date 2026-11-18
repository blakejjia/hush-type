# App Simplification and Cursor-Driven Floating Mic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify Hashtype by removing redundant settings, introducing automatic Material You dynamic theming, and transforming the floating mic into a lightweight, cursor-driven tool that only displays when an input cursor is active.

**Architecture:**
- **UI / Settings Layer (Flutter)**: Clean up `SettingsPage` by stripping "Appearance" and "Keyboard" sections. Use `dynamic_color` with Material You palette and `ThemeMode.system` in `main.dart`. Remove legacy mute/fold/hide configurations.
- **Service Layer (Kotlin)**: Re-architect `HashtypeFloatingService` from an always-on widget into a cursor-driven overlay using Android Accessibility focus events (`FOCUS_INPUT`). Remove legacy dismiss overlay, 15m/24h muting, auto-fold, and orientation/game-based hiding. Provide simple single-click toggle recording and screen-clamped drag repositioning.
- **Documentation**: Overhaul `AGENTS.md` at root to document the full architecture, lifecycle, and shared settings.

**Tech Stack:** Flutter (Dart 3, Material 3, dynamic_color), Android Native Kotlin (AccessibilityService, WindowManager, DynamicColors, OkHttp).

**Spec:** `docs/superpowers/specs/2026-11-18-simplify-app-and-floating-mic-design.md`

## Global Constraints
- Target Android SDK: compileSdk 35 / minSdk 24
- SharedPreferences name: `"FlutterSharedPreferences"`
- License: GPL v3
- All Dart code must pass `flutter analyze` with zero errors or warnings.

## Review Focus
1. Accessibility input focus detection must accurately recognize `EditText` input focus without flickering during rapid field changes.
2. Active recording or LLM processing must not be prematurely hidden if the input window focus briefly shifts before text insertion completes.
3. Fallback color scheme (`Colors.blue`) must work seamlessly when dynamic color is null on older Android versions.
4. Floating mic touch events must cleanly distinguish between a tap (triggering mic) and drag (repositioning).
5. All references to legacy keys (`floating_mic_muted_until`, `floating_mic_auto_fold`, `floating_mic_hide_in_landscape`, `floating_mic_hide_in_games`) must be completely purged.

---

### Task 1: Comprehensive Rewrite of `AGENTS.md`

**Files:**
- Modify: `AGENTS.md`

**Interfaces:**
- Produces: Updated `AGENTS.md` covering the entire dual-layer architecture, accessibility floating mic lifecycle, shared settings, and development commands.

- [ ] **Step 1: Write updated `AGENTS.md`**
  Detail the Flutter App + IME Service + Accessibility Floating Service architecture, the cursor-driven floating mic lifecycle, the shared SharedPreferences schema, dynamic theming, and dev workflows.

- [ ] **Step 2: Verify `AGENTS.md` contents**
  Ensure all sections are accurate, comprehensive, and reflect the simplified codebase without legacy references.

- [ ] **Step 3: Commit**
  ```bash
  git add AGENTS.md
  git commit -m "docs: overhaul AGENTS.md with complete architecture and simplified floating mic specs"
  ```

---

### Task 2: System Dynamic Theming & Removal of Appearance Settings

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Delete: `lib/pages/settings/theme_color_page.dart`
- Modify: `lib/services/theme_manager.dart`

**Interfaces:**
- Consumes: `dynamic_color` package for Material You.
- Produces: `DynamicColorBuilder` root theme with `ThemeMode.system` and `Colors.blue` fallback.

- [ ] **Step 1: Add `dynamic_color: ^1.7.0` to `pubspec.yaml`**
  Add dependency under `dependencies:` in `pubspec.yaml`.

- [ ] **Step 2: Run `flutter pub get`**
  Run: `flutter pub get`
  Expected: Success, resolving `dynamic_color`.

- [ ] **Step 3: Update `lib/main.dart` with `DynamicColorBuilder`**
  Wrap `MaterialApp` in `DynamicColorBuilder`. Harmonize dynamic light/dark palettes or fallback to `ColorScheme.fromSeed(seedColor: Colors.blue)`. Use `themeMode: ThemeMode.system`. Keep `GoogleFonts.outfitTextTheme()`.

- [ ] **Step 4: Remove `ThemeColorPage` and clean `theme_manager.dart`**
  Delete `lib/pages/settings/theme_color_page.dart`. Simplify `ThemeManager` or adapt it so that it does not manage custom color/dark mode toggles.

- [ ] **Step 5: Run `flutter analyze`**
  Run: `flutter analyze`
  Expected: No errors related to theme.

- [ ] **Step 6: Commit**
  ```bash
  git add pubspec.yaml pubspec.lock lib/main.dart lib/services/theme_manager.dart
  git rm lib/pages/settings/theme_color_page.dart
  git commit -m "feat: adopt system dynamic color and remove manual appearance settings"
  ```

---

### Task 3: Clean up Settings Page, AppSettingsService, and TestPage

**Files:**
- Modify: `lib/pages/settings/settings_page.dart`
- Modify: `lib/services/app_settings_service.dart`
- Modify: `lib/pages/test/test_page.dart`

**Interfaces:**
- Produces: Simplified `SettingsPage` with no Appearance or Keyboard sections; `floating_mic_enabled` defaulting to `true`; no legacy mute/fold/hide options.

- [ ] **Step 1: Update `AppSettingsService`**
  - Change default for `getFloatingMicEnabled()` to `true`.
  - Remove all methods and keys for `floating_mic_muted_until`, `floating_mic_auto_fold`, `floating_mic_hide_in_landscape`, and `floating_mic_hide_in_games`.

- [ ] **Step 2: Update `SettingsPage` (`lib/pages/settings/settings_page.dart`)**
  - Remove `Appearance` section (`Theme Color` and `Dark Mode` tiles).
  - Remove `Keyboard` section (`Enable Keyboard` and `Show Period Button` tiles).
  - In `Floating Voice Input` section:
    - Default switch to enabled.
    - Remove `Auto Fold on Border`, `Hide in Landscape Mode`, `Hide in Games` tiles.
    - Retain `Enable Floating Mic`, `Auto-Paste Helper`, and `Customize Floating Mic`.

- [ ] **Step 3: Update `TestPage` (`lib/pages/test/test_page.dart`)**
  - Remove `_buildRestoreFloatingMicCard` and `_restoreFloatingMic` logic.
  - Retain `TextField` and status checks.

- [ ] **Step 4: Run `flutter analyze`**
  Run: `flutter analyze`
  Expected: 0 issues found.

- [ ] **Step 5: Commit**
  ```bash
  git add lib/pages/settings/settings_page.dart lib/services/app_settings_service.dart lib/pages/test/test_page.dart
  git commit -m "refactor: simplify settings page and purge legacy floating mic configurations"
  ```

---

### Task 4: Overhaul `HashtypeFloatingService` to Cursor-Driven Overlay

**Files:**
- Modify: `android/app/src/main/res/xml/accessibility_service_config.xml`
- Delete: `android/app/src/main/res/layout/layout_dismiss_targets.xml`
- Modify: `android/app/src/main/kotlin/com/jia_yx/hashtype/HashtypeFloatingService.kt`

**Interfaces:**
- Consumes: Accessibility events `typeViewFocused|typeViewTextSelectionChanged|typeWindowStateChanged|typeWindowsChanged`.
- Produces: Lightweight overlay that only appears when an editable input field is focused, with single-tap recording and screen-clamped drag repositioning.

- [ ] **Step 1: Update `accessibility_service_config.xml`**
  Set `android:accessibilityEventTypes="typeViewFocused|typeViewTextSelectionChanged|typeWindowStateChanged|typeWindowsChanged"`, `android:notificationTimeout="100"`, `android:canRetrieveWindowContent="true"`, and `android:accessibilityFlags="flagDefault|flagRetrieveInteractiveWindows"`.

- [ ] **Step 2: Delete `layout_dismiss_targets.xml`**
  Delete `android/app/src/main/res/layout/layout_dismiss_targets.xml`.

- [ ] **Step 3: Overhaul `HashtypeFloatingService.kt`**
  - Remove all legacy code:
    - Dismiss targets overlay & 15m/24h mute (`dismissOverlayView`, `dismissOverlayParams`, `showDismissOverlay`, `hideDismissOverlay`, `dismissAndMuteWidget`, `muteHandler`, `isMuted`, etc.).
    - Auto fold (`foldWidget`, `unfoldWidgetInstantly`, `checkAndFoldWidgetIfNeeded`, `isFolded`, `foldedSide`, `foldAnimator`).
    - Orientation / game hiding (`autoHideLandscape`, `isHiddenDueToLandscape`, `isAppGame`, `gameCache`, `isHiddenDueToGame`, `handlePackageChanged`).
    - Long-press push-to-talk (`longPressRunnable`, `isLongPressTriggered`, `cancelRecordingRunnable`).
  - Implement cursor-driven visibility:
    - Method `isInputActive(): Boolean` querying `rootInActiveWindow` and active windows for `findFocus(AccessibilityNodeInfo.FOCUS_INPUT)`. Check `node.isEditable && node.isFocused`.
    - In `onAccessibilityEvent(event)`:
      - If input is active: cancel pending hide runnable, show floating mic if enabled.
      - If input is not active and `viewModel.getCurrentState() is VoiceImeViewModel.ImeState.Idle`: schedule hide with 200ms debounce.
  - Implement state-aware persistence:
    - In `onStateChanged(state)`:
      - When `Recording` or `Processing`: keep visible regardless of focus.
      - When `Idle`: re-evaluate `isInputActive()` and hide if not active.
  - Implement clean touch handling:
    - ACTION_DOWN: record initial x/y, `isDragging = false`.
    - ACTION_MOVE: if delta > touchSlop, `isDragging = true`, update `layoutParams.x/y` clamped to screen dimensions.
    - ACTION_UP: if not dragging, `vibrate()` and `viewModel.handleMicClick()`.

- [ ] **Step 4: Check Kotlin compilation with Gradle**
  Run: `flutter build apk --debug` or `./gradlew compileDebugKotlin` from `android/`
  Expected: Successful compilation without errors.

- [ ] **Step 5: Commit**
  ```bash
  git rm android/app/src/main/res/layout/layout_dismiss_targets.xml
  git add android/app/src/main/res/xml/accessibility_service_config.xml android/app/src/main/kotlin/com/jia_yx/hashtype/HashtypeFloatingService.kt
  git commit -m "feat: overhaul floating mic to cursor-driven lifecycle with single-tap toggle"
  ```

---

### Task 5: End-to-End Verification and Cleanup

**Files:**
- All project files

- [ ] **Step 1: Run `flutter analyze`**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 2: Check for any remaining legacy references**
  Search codebase for any dead references to `floating_mic_auto_fold`, `floating_mic_muted_until`, `floating_mic_hide`, etc.
  Verify zero remaining occurrences.

- [ ] **Step 3: Verification build**
  Run: `flutter build apk --debug`
  Expected: Build succeeds.
