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
sudo dpkg -i foxtimer_1.3.4_amd64.deb
# Fix any missing dependencies:
sudo apt-get install -f
```

### Uninstalling

```bash
sudo dpkg -r foxtimer
```

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
