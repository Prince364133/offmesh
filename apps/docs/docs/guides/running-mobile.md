---
sidebar_position: 2
title: Running the Mobile App (Flutter & Android)
description: Step-by-step instructions for running the NearLink Flutter client on Android emulators and physical devices.
---

# Running the Mobile Application

The NearLink client in [`apps/mobile/`](file:///c:/Users/saavi/Desktop/offline-messaging/apps/mobile/) is built using **Flutter 3.47** (Dart 3.13) with native platform bridges for Bluetooth Low Energy, Wi-Fi Direct, and Android KeyStore hardware cryptography.

---

## 1. Prerequisites

- **Flutter SDK:** 3.24+ (Recommended: 3.47.2+)
- **Android SDK Platform:** Android 14 (API 34) or 15 (API 35)
- **Java Development Kit:** OpenJDK 21
- **Physical Device or Emulator:**
  - Android 12+ (API 31+) required for modern Bluetooth permissions (`BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`).
  - Google Play Services are **optional** (the app runs fully on pure AOSP).

---

## 2. Running Automated Tests

Run the client unit tests to verify wire parsing, cryptographic safety codes, and state machines:

```bash
cd apps/mobile
flutter test
```

Expected output:
```text
00:02 +5: All tests passed!
```

---

## 3. Launching on an Android Emulator

1. Start your Android Emulator (e.g. `Pixel_7_API_34`):
   ```bash
   emulator -avd Pixel_7_API_34 -netdelay none -netspeed full
   ```
2. Verify ADB device connectivity:
   ```bash
   adb devices
   ```
3. Run the Flutter app in debug mode:
   ```bash
   cd apps/mobile
   flutter run -d emulator-5554
   ```

---

## 4. Assembling a Production Debug APK

To compile the standalone debug APK for physical device deployment:

```bash
cd apps/mobile
flutter build apk --debug
```

The compiled package will be located at:
```text
apps/mobile/build/app/outputs/flutter-apk/app-debug.apk
```

Install directly via ADB:
```bash
adb install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk
```

---

## 5. Connecting Mobile Client to Local Gateway Server

When running on an Android Emulator:
- The host workstation is accessible via IP: `10.0.2.2`.
- Server Gateway URL: `http://10.0.2.2:3000`
- WebSocket Gateway: `ws://10.0.2.2:3000/ws`

When running on a physical Android device:
- Connect the smartphone to the same Wi-Fi network as your workstation.
- Use your workstation's local LAN IP (e.g. `http://192.168.1.150:3000`).
