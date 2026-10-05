# FoxTimer

A simple cross-platform Pomodoro timer built with Flutter.

---

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.10 or later (tested on 3.48.0)
- Dart SDK ^3.9.2 (bundled with Flutter)
- For Linux builds: CMake ≥ 3.13, Ninja, GTK3 development libraries, `pkg-config`
- For packaging as `.deb`: `dpkg-deb` (standard on Debian/Ubuntu)

### Install Linux build dependencies (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y cmake ninja-build pkg-config \
  libgtk-3-dev libblkid-dev liblzma-dev
```

---

## Getting dependencies

```bash
flutter pub get
```

---

## Running in development

```bash
flutter run -d linux
```

---

## Building a release

### Linux

```bash
flutter build linux --release
```

The compiled bundle is placed at:

```
build/linux/x64/release/bundle/
├── foxtimer          # executable
├── lib/              # shared libraries
└── data/             # Flutter assets and ICU data
```

> The bundle directory is self-contained and relocatable as long as `data/` and `lib/` stay next to the binary.

### Other platforms

```bash
flutter build apk --release       # Android
flutter build ios --release       # iOS (macOS host required)
flutter build macos --release     # macOS
flutter build windows --release   # Windows
flutter build web --release       # Web
```

---

## Packaging as a .deb (Linux)

After running `flutter build linux --release`, use the bundled
[`package_deb.sh`](package_deb.sh) script to produce a Debian package. It needs
`dpkg-deb` and ImageMagick (`convert`).

The script installs the desktop entry, the `StartupWMClass` and the themed icon
all named after `APPLICATION_ID` (`com.example.foxtimer`), which must match the
value in `linux/CMakeLists.txt`. This is what lets the taskbar and alt-tab
window switcher associate the running window with the app icon — a plain
`foxtimer.desktop` name does not match the window's `WM_CLASS`/app-id and leaves
the window iconless.

Run it from the project root:

```bash
flutter build linux --release
bash package_deb.sh
```

### Installing the .deb

```bash
sudo dpkg -i foxtimer_1.4.0_amd64.deb
# Fix any missing dependencies:
sudo apt-get install -f
```

### Uninstalling

```bash
sudo dpkg -r foxtimer
```

---

## Testing

```bash
flutter test                                              # unit + widget tests
flutter test integration_test/app_test.dart -d linux      # end-to-end on desktop
```

### Android instrumentation tests

Start an emulator (or plug in a device), then either run them through Flutter:

```bash
flutter emulators --launch <emulator-id>
adb shell pm grant com.example.foxtimer android.permission.POST_NOTIFICATIONS  # after the app is installed once
flutter test integration_test -d <device-id>
```

or as JUnit instrumentation tests through Gradle (results in
`build/app/outputs/androidTest-results/`):

```bash
cd android
./gradlew app:connectedDebugAndroidTest \
  -Ptarget=`pwd`/../integration_test/android_test.dart
```

`integration_test/android_test.dart` covers the phone layout, numeric inputs,
real-time countdown, catch-up after Android suspends the app in the
background, the end-of-cycle alarms/notifications, the task list, the system
back button and audio playback. The suspend test blocks the app for ~2 minutes
on purpose, and the alarm test waits ~1 minute for a real alarm to fire.
`MainActivityTest` grants the notification permission itself.

---

## Android: end-of-cycle alerts in the background

Android delays or freezes a backgrounded app's timers, so while the app is in
the background the upcoming phase ends (the next 12) are scheduled as exact
alarms that post a notification with the default sound
(`android/app/src/main/res/raw/town.ogg`). Opening the app again cancels them.
Notifications need the user to allow them (asked on the first *Iniciar*);
exact timing uses `USE_EXACT_ALARM`, which Google Play only accepts for apps
whose core function is an alarm/timer.

---

## Project structure

```
foxtimer/
├── lib/               # Dart source code
├── assets/            # Bundled assets (sounds, etc.)
├── linux/             # Linux-specific CMake build files
├── android/           # Android platform code
├── ios/               # iOS platform code
├── macos/             # macOS platform code
├── windows/           # Windows platform code
├── web/               # Web platform code
├── test/              # Unit tests
├── integration_test/  # Integration tests
└── pubspec.yaml       # Project manifest and dependencies
```

---

## Resources

- [Flutter documentation](https://docs.flutter.dev/)
- [Flutter Linux desktop support](https://docs.flutter.dev/platform-integration/linux/building)
- [Dart packages (pub.dev)](https://pub.dev/)
