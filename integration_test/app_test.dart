// Real end-to-end tests: run on an actual device/desktop binding (not the
// fake-time flutter_test binding), so real plugins (media_kit/just_audio)
// execute for real. Run with:
//   flutter test integration_test/app_test.dart -d linux
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:foxtimer/main.dart';

Future<void> _setConfig(
  WidgetTester tester, {
  required String work,
  required String shortBreak,
  required String longBreak,
  required String cycles,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), work);
  await tester.enterText(fields.at(1), shortBreak);
  await tester.enterText(fields.at(2), longBreak);
  await tester.enterText(fields.at(3), cycles);
  await tester.ensureVisible(find.text('Aplicar'));
  await tester.tap(find.text('Aplicar'));
  await tester.pumpAndSettle();
}

// The timer body is taller than the default 1280x720 window, so buttons
// below the fold need to be scrolled into view before tapping.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (Platform.isLinux) {
      MediaKit.ensureInitialized();
    }
  });

  testWidgets('navigating tabs and settings does not crash the real app', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('FoxTimer Pomodoro'), findsOneWidget);

    await tester.tap(find.text('Tarefas'));
    await tester.pumpAndSettle();
    expect(find.text('O que precisa ser feito?'), findsOneWidget);

    await tester.tap(find.text('Timer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Configurações'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('FoxTimer Pomodoro'), findsOneWidget);
  });

  testWidgets(
    'playing/stopping a sound preview in Settings does not break the next '
    'real end-of-cycle sound (regression test for the media_kit stop() bug: '
    'stop() used to run playlist-clear, unloading the media so a later '
    'play() silently did nothing)',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await _setConfig(
        tester,
        work: '1',
        shortBreak: '1',
        longBreak: '1',
        cycles: '2',
      );

      // Reproduce the exact regression scenario: preview a sound in
      // Settings, stop it, then leave the screen.
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      await tester.tap(find.text('Parar'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Start the (real, 1-minute) work session and let it run to
      // completion for real.
      await _tapVisible(tester, find.text('Iniciar'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The cycle must have actually completed and moved on to the short
      // break with its end-of-cycle snackbar and stop action — proving the
      // sound path is still functional after being used once in Settings.
      expect(find.text('Pausa curta! Descanse bastante.'), findsOneWidget);
      expect(find.text('Parar som'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
