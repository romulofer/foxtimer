import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  await tester.tap(find.text('Aplicar'));
  await tester.pump();
}

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      MediaKit.ensureInitialized();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> setLargeSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('start, pause and reset drive the visible timer state', (
    tester,
  ) async {
    await setLargeSurface(tester);
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await _setConfig(
      tester,
      work: '1',
      shortBreak: '1',
      longBreak: '1',
      cycles: '2',
    );
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);

    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(find.text('Pausar'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('00:55'), findsOneWidget);

    await tester.tap(find.text('Pausar'));
    await tester.pump();
    expect(find.text('Iniciar'), findsOneWidget);
    // Paused: no further ticks should occur.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('00:55'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(find.text('01:00'), findsOneWidget);
  });

  testWidgets(
    'a completed work cycle shows the end-of-cycle snackbar with a Parar som action',
    (tester) async {
      await setLargeSurface(tester);
      await tester.pumpWidget(const MyApp());
      await tester.pump();

      await _setConfig(
        tester,
        work: '1',
        shortBreak: '1',
        longBreak: '1',
        cycles: '2',
      );

      await tester.tap(find.text('Iniciar'));
      await tester.pump();

      // Drive the 1-minute work session to completion; the periodic Timer
      // runs inside flutter_test's fake-async zone, so this is instant in
      // wall-clock time. 61 ticks: the 60th brings the display to 00:00,
      // the 61st is the one that detects zero and fires completion.
      await tester.pump(const Duration(seconds: 61));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pausa curta! Descanse bastante.'), findsOneWidget);
      expect(find.text('Parar som'), findsOneWidget);

      // Tapping "Parar som" must not throw even though no real audio
      // backend is available in the test environment.
      await tester.tap(find.text('Parar som'));
      await tester.pump();

      // The next cycle (short break -> work) already auto-started.
      expect(find.text('Pausar'), findsOneWidget);
    },
  );

  testWidgets('switching to the Tarefas tab shows the todo list', (
    tester,
  ) async {
    await setLargeSurface(tester);
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('O que precisa ser feito?'), findsNothing);

    await tester.tap(find.text('Tarefas'));
    await tester.pumpAndSettle();

    expect(find.text('O que precisa ser feito?'), findsOneWidget);
  });

  testWidgets('opening settings and navigating back returns to the timer', (
    tester,
  ) async {
    await setLargeSurface(tester);
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Configurações'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('FoxTimer Pomodoro'), findsOneWidget);
  });
}
