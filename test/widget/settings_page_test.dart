import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foxtimer/models/sound_option.dart';
import 'package:foxtimer/screens/settings_page.dart';

class _Recorder {
  ThemeMode? lastThemeMode;
  final playedSounds = <SoundOption>[];
  int stopCalls = 0;

  void onThemeModeChanged(ThemeMode mode) {
    lastThemeMode = mode;
  }

  Future<void> onPlayTestSound(SoundOption sound, double volume) async {
    playedSounds.add(sound);
  }

  Future<void> onStopSound() async {
    stopCalls++;
  }
}

Widget _wrap(_Recorder r, {ThemeMode themeMode = ThemeMode.system}) {
  return MaterialApp(
    home: SettingsPage(
      themeMode: themeMode,
      onThemeModeChanged: r.onThemeModeChanged,
      onPlayTestSound: r.onPlayTestSound,
      onStopSound: r.onStopSound,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('loads and shows theme options plus the default sound', (
    tester,
  ) async {
    final r = _Recorder();
    await tester.pumpWidget(_wrap(r));
    await tester.pumpAndSettle();

    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    expect(find.text(bundledSounds.first.label), findsOneWidget);
  });

  testWidgets('selecting a theme segment calls onThemeModeChanged', (
    tester,
  ) async {
    final r = _Recorder();
    await tester.pumpWidget(_wrap(r, themeMode: ThemeMode.system));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(r.lastThemeMode, ThemeMode.dark);
  });

  testWidgets('turning sound off disables volume slider and stops playback', (
    tester,
  ) async {
    final r = _Recorder();
    await tester.pumpWidget(_wrap(r));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);

    expect(r.stopCalls, greaterThanOrEqualTo(1));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('soundEnabled'), isFalse);
    // The full sound preference trio is persisted together on every save.
    expect(prefs.getString('selectedSoundId'), bundledSounds.first.id);
  });

  testWidgets('play button on a sound row invokes onPlayTestSound with that sound', (
    tester,
  ) async {
    final r = _Recorder();
    await tester.pumpWidget(_wrap(r));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pumpAndSettle();

    expect(r.playedSounds, hasLength(1));
    expect(r.playedSounds.single.id, bundledSounds.first.id);

    // Icon flips to the stop variant while "playing".
    expect(find.byIcon(Icons.stop_circle), findsOneWidget);
  });

  testWidgets('the global Parar button appears while a sound is playing and calls onStopSound', (
    tester,
  ) async {
    final r = _Recorder();
    await tester.pumpWidget(_wrap(r));
    await tester.pumpAndSettle();

    expect(find.text('Parar'), findsNothing);

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pumpAndSettle();

    expect(find.text('Parar'), findsOneWidget);

    await tester.tap(find.text('Parar'));
    await tester.pumpAndSettle();

    expect(r.stopCalls, 1);
    expect(find.text('Parar'), findsNothing);
  });

  testWidgets('the bundled sound starts selected', (tester) async {
    final r = _Recorder();
    await tester.pumpWidget(_wrap(r));
    await tester.pumpAndSettle();

    final radio = tester.widget<RadioListTile<String>>(
      find.byType(RadioListTile<String>).first,
    );
    expect(radio.value, bundledSounds.first.id);
    expect(radio.groupValue, bundledSounds.first.id);
  });
}
