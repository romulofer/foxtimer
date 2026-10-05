import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foxtimer/main.dart';
import 'package:foxtimer/services/cycle_notifications.dart';

class _FakeNotifications extends CycleNotifications {
  final scheduled = <List<CycleEnd>>[];
  bool? lastWithSound;
  int cancels = 0;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<bool> schedule(List<CycleEnd> ends, {required bool withSound}) async {
    scheduled.add(ends);
    lastWithSound = withSound;
    return true;
  }

  @override
  Future<void> cancelAll() async => cancels++;
}

Future<void> _setLifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

const _toBackground = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const _toForeground = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

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
    PackageInfo.setMockInitialValues(
      appName: 'foxtimer',
      packageName: 'com.example.foxtimer',
      version: '1.4.0',
      buildNumber: '8',
      buildSignature: '',
    );
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

    // Both tabs pre-rendered. The add-todo button sits behind IgnorePointer
    // while the Timer tab is active — not interactable until tab switches.
    expect(find.byIcon(Icons.add).hitTestable(), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Tarefas'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'timer keeps ticking while on Tarefas tab (IndexedStack keeps both alive)',
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

      // Advance 10 s on the Timer tab (t=0 → t=10, 10 ticks, remaining=50)
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('00:50'), findsOneWidget);

      // Switch to Tarefas — use fixed pump to avoid pumpAndSettle advancing
      // fake-async past a 1-s timer boundary (tab animation is ~300 ms)
      await tester.tap(find.widgetWithText(Tab, 'Tarefas'));
      await tester.pump(const Duration(milliseconds: 400));

      // Advance 10 more seconds while on Tarefas tab (t=10.4 → t=20.4, 10 ticks)
      await tester.pump(const Duration(seconds: 10));

      // Switch back to Timer; total 20 ticks → remaining=40
      await tester.tap(find.widgetWithText(Tab, 'Timer'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('00:40'), findsOneWidget);
    },
  );

  testWidgets('switching tabs multiple times preserves timer state', (
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

    // Switch back and forth 5 times without starting timer
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.widgetWithText(Tab, 'Tarefas'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Timer'));
      await tester.pumpAndSettle();
    }

    // Timer state unchanged
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
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

  testWidgets('fits a phone screen and scrolls a long todo list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({
      'todos':
          '[${List.generate(30, (i) => '{"title":"Tarefa $i","done":false}').join(',')}]',
    });

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    // Any RenderFlex overflow would surface here as a test failure.
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(Tab, 'Tarefas'));
    await tester.pumpAndSettle();

    final last = find.text('Tarefa 29');
    expect(last.hitTestable(), findsNothing);
    await tester.scrollUntilVisible(
      last,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(last.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('background alerts', () {
    late _FakeNotifications notifications;
    late CycleNotifications original;

    setUp(() {
      original = CycleNotifications.instance;
      notifications = _FakeNotifications();
      CycleNotifications.instance = notifications;
    });
    tearDown(() => CycleNotifications.instance = original);

    testWidgets(
      'going to background schedules the upcoming phase ends; resume cancels',
      (tester) async {
        await setLargeSurface(tester);
        await tester.pumpWidget(const MyApp());
        await tester.pump();
        await _setConfig(
          tester,
          work: '1',
          shortBreak: '1',
          longBreak: '2',
          cycles: '2',
        );

        await tester.tap(find.text('Iniciar'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 10));

        await _setLifecycle(tester, _toBackground);
        final ends = notifications.scheduled.single;
        expect(ends, hasLength(12));
        expect(notifications.lastWithSound, isTrue);

        // Work (50 s left) -> short break 1 min -> work 1 min -> long break
        // 2 min -> work 1 min, same chain the running timer follows.
        expect(
          ends.first.at.difference(clock.now()),
          const Duration(seconds: 50),
        );
        final gaps = [
          for (var i = 1; i < 5; i++) ends[i].at.difference(ends[i - 1].at),
        ];
        expect(gaps, const [
          Duration(minutes: 1),
          Duration(minutes: 1),
          Duration(minutes: 2),
          Duration(minutes: 1),
        ]);
        expect(ends.take(4).map((e) => e.message), const [
          'Pausa curta! Descanse bastante.',
          'Hora de focar novamente!',
          'Pausa longa! Descanse bastante.',
          'Hora de focar novamente!',
        ]);

        final cancelsBefore = notifications.cancels;
        await _setLifecycle(tester, _toForeground);
        expect(notifications.cancels, cancelsBefore + 1);

        await tester.tap(find.text('Pausar'));
        await tester.pump();
      },
    );

    testWidgets('nothing is scheduled when the timer is not running', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await tester.pumpWidget(const MyApp());
      await tester.pump();

      await _setLifecycle(tester, _toBackground);
      expect(notifications.scheduled, isEmpty);
      await _setLifecycle(tester, _toForeground);
    });
  });
}
