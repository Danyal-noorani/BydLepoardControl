# BYD Display Switcher

A Flutter Android app that adds a floating overlay button for routing apps to different displays on multi-screen BYD vehicles.

**Tested on:** BYD Leopard 5 Ultra

---

## What it does

Tap the floating teal button to see your recently-used apps. Tap an app, then pick a display (Driver's / Main / Passenger's) — the app launches on that screen via `am start --display`.

The host app also lets you adjust per-display DPI (zoom in/out or reset).

---

## Requirements

- Android device with multiple displays (BYD Leopard 5 Ultra or similar)
- Wireless ADB enabled on the device (`adb tcpip 5555`)
- Two permissions granted manually in Settings:
  - **Display over other apps** (`SYSTEM_ALERT_WINDOW`)
  - **Usage access** (`PACKAGE_USAGE_STATS`) — Settings > Special app access > Usage access

---

## Setup

1. Enable wireless debugging on the car head unit and ensure the device is reachable over Wi-Fi.
2. The app connects to itself via ADB over loopback (`<device-wifi-ip>:5555`). On first launch it will prompt you to authorise the ADB key.

```bash
flutter pub get
flutter build apk
# then install the APK on the device
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Architecture

The app runs two Flutter engine isolates:

| Isolate | Entry point | Role |
|---|---|---|
| Host app | `main()` / `HomeScreen` | Has access to native MethodChannels |
| Overlay UI | `overlayMain()` / `OverlayWidget` | Draws the floating panel; uses ADB for native calls |

Because `flutter_overlay_window` spawns the overlay in a separate engine, it cannot call native MethodChannels directly. All shell commands (listing running apps, launching activities) are executed through `SelfAdbService`, which opens an ADB shell over the device's own Wi-Fi IP.

### Native MethodChannel

Channel: `com.byd_display_switcher/device`

| Method | Description |
|---|---|
| `getRunningApps` | Returns the 20 most-recently-used apps via `UsageStatsManager` |
| `executeShellCommand` | Runs an arbitrary shell command and returns stdout |

### Key files

```
lib/
  main.dart               # Host app + HomeScreen (DPI controls, overlay toggle)
  overlay_widget.dart     # Floating overlay UI (app list + display picker)
  services/
    device_service.dart   # SelfAdbService — ADB-over-WiFi loopback client
android/
  app/src/main/
    kotlin/.../MainActivity.kt   # MethodChannel handlers
    AndroidManifest.xml          # SYSTEM_ALERT_WINDOW, PACKAGE_USAGE_STATS
```

---

## Known issues

- `DeviceService` declares channel `com.yourapp/device`; `MainActivity.kt` registers `com.byd_display_switcher/device`. These must match for MethodChannel calls to work.
- `device_apps 2.2.0` (used for fetching app icons/names) is discontinued and requires a one-line patch to its `build.gradle` (`namespace 'fr.g123k.deviceapps'`) when building with AGP 7.3+. The patch lives in `~/.pub-cache` and must be re-applied if the pub cache is cleared.
