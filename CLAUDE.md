# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run on connected Android device
flutter run

# Build APK
flutter build apk

# Run linter
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/some_test.dart
```

> Android-only app. iOS is not a supported target.

## Architecture

This is a Flutter Android app that renders a draggable floating overlay (system alert window) on top of other apps. The overlay lets the user pick a display destination (d1/d2/d3) and then select from recently-used apps to route to that display.

### Two-isolate design

`flutter_overlay_window` runs the overlay UI in a **separate Flutter engine isolate** with its own entry point:

- `main()` → host app (`HomeScreen`) — has access to native MethodChannels
- `overlayMain()` → overlay UI (`OverlayWidget`) — **cannot** call MethodChannels directly

Because the overlay isolate is isolated from the host, all native calls must be proxied:

1. `OverlayWidget` sends a request via `FlutterOverlayWindow.shareData({'action': 'getRunningApps'})`
2. `HomeScreen.initState` listens on `FlutterOverlayWindow.overlayListener`, calls the native MethodChannel, and sends results back via `shareData({'action': 'runningApps', 'apps': ...})`
3. `OverlayWidget.overlayListener` receives the result and updates state

Any new native capability must follow this same request/response pattern through `HomeScreen`.

### Native bridge (`MainActivity.kt`)

MethodChannel: `com.byd_display_switcher/device`

| Method | Behaviour |
|---|---|
| `getRunningApps` | Queries `UsageStatsManager` for the last 3 hours, returns top 20 apps sorted by `lastTimeUsed` as `List<Map<packageName, appName>>` |
| `executeShellCommand` | Runs an arbitrary shell command via `Runtime.getRuntime().exec(["sh", "-c", cmd])` and returns stdout (or `ERR: <stderr>`) |

Required Android permissions (already declared in `AndroidManifest.xml`):
- `SYSTEM_ALERT_WINDOW` — to draw the overlay
- `PACKAGE_USAGE_STATS` — for `getRunningApps` (must be granted manually in Settings > Special app access)

### Known bug

`DeviceService` (`lib/services/device_service.dart`) declares channel `'com.yourapp/device'`, but `MainActivity.kt` registers `'com.byd_display_switcher/device'`. The names must match for MethodChannel calls to succeed.

### Overlay UI states

`OverlayWidget` cycles through three states (`_State` enum):

- `hidden` — only the circular FAB is visible
- `menu` — dropdown showing display options (currently hardcoded `['d1', 'd2', 'd3']`)
- `apps` — scrollable list of recently-used apps; tapping an app should trigger display switching (handler is a TODO placeholder)
