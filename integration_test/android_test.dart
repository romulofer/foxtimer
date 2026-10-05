// Android instrumentation tests: run on a real device/emulator with real
// plugins (just_audio, shared_preferences) and real wall-clock time.
//
//   flutter test integration_test/android_test.dart -d <emulator-id>
//
// or through Gradle/JUnit (MainActivityTest.kt):
//
//   cd android && ./gradlew app:connectedDebugAndroidTest \
//     -Ptarget=`pwd`/../integration_test/android_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foxtimer/main.dart';
import 'package:foxtimer/services/cycle_notifications.dart';

// Stands in for the real alerts where a test blocks the isolate: a real
// alarm firing then would hit a blocked main thread.
class _NoopNotifications extends CycleNotifications {
  @override
  Future<void> requestPermission() async {}

  @override
  Future<bool> schedule(List<CycleEnd> ends, {required bool withSound}) async =>
      false;

  @override
  Future<void> cancelAll() async {}
}

final _clockText = RegExp(r'^\d\d:\d\d$');

Future<void> _launch(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

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
  await _tapVisible(tester, find.text('Aplicar'));
  await tester.pumpAndSettle();
}

// Phone screens are shorter than the timer page, so controls below the fold
// need to be scrolled into view before tapping.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

// Seconds shown by the countdown (the only "mm:ss" text on screen).
int _displayedSeconds(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .singleWhere(_clockText.hasMatch);
  final parts = text.split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}

Finder get _todoField => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'O que precisa ser feito?',
);

Future<void> _setLifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final realNotifications = CycleNotifications.instance;

  setUp(() async {
    CycleNotifications.instance = realNotifications;
    // Each test starts from a fresh install state.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  testWidgets('timer page lays out on the phone screen without overflow', (
    tester,
  ) async {
    await _launch(tester);

    expect(find.text('FoxTimer Pomodoro'), findsOneWidget);
    expect(_displayedSeconds(tester), 25 * 60);

    // Every control must be reachable by scrolling on a phone.
    await tester.ensureVisible(find.text('Iniciar'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar').hitTestable(), findsOneWidget);
    expect(find.byIcon(Icons.refresh).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cycle inputs accept digits only from the number keyboard', (
    tester,
  ) async {
    await _launch(tester);

    final work = find.byType(TextField).at(0);
    await tester.enterText(work, '2a.5-');
    await tester.pump();

    expect(tester.widget<TextField>(work).controller!.text, '25');
  });

  testWidgets('Aplicar saves the cycle and hides the soft keyboard', (
    tester,
  ) async {
    await _launch(tester);

    await tester.tap(find.byType(TextField).at(0));
    await tester.pump();
    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .any((e) => e.focusNode.hasFocus),
      isTrue,
    );

    await _setConfig(
      tester,
      work: '30',
      shortBreak: '7',
      longBreak: '20',
      cycles: '3',
    );

    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .any((e) => e.focusNode.hasFocus),
      isFalse,
    );
    expect(_displayedSeconds(tester), 30 * 60);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('workMinutes'), 30);
    expect(prefs.getInt('shortBreakMinutes'), 7);
    expect(prefs.getInt('longBreakMinutes'), 20);
    expect(prefs.getInt('cyclesBeforeLongBreak'), 3);
  });

  testWidgets('countdown follows real time; pause freezes it', (tester) async {
    await _launch(tester);
    await _setConfig(
      tester,
      work: '1',
      shortBreak: '1',
      longBreak: '1',
      cycles: '2',
    );

    await _tapVisible(tester, find.text('Iniciar'));
    await tester.pump();

    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pump();
    final afterRun = _displayedSeconds(tester);
    expect(afterRun, inInclusiveRange(56, 57));

    await _tapVisible(tester, find.text('Pausar'));
    await tester.pump();
    final paused = _displayedSeconds(tester);

    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();
    expect(_displayedSeconds(tester), paused);

    await _tapVisible(tester, find.byIcon(Icons.refresh));
    await tester.pump();
    expect(_displayedSeconds(tester), 60);
  });

  testWidgets(
    'after Android suspends the app, resume catches up on every elapsed phase',
    (tester) async {
      CycleNotifications.instance = _NoopNotifications();
      await _launch(tester);
      await _setConfig(
        tester,
        work: '1',
        shortBreak: '1',
        longBreak: '1',
        cycles: '2',
      );

      await _tapVisible(tester, find.text('Iniciar'));
      await tester.pump();

      // Background the app, then block the isolate so no Dart timer can
      // fire — the same thing Android's cached-app freezer does to a
      // backgrounded app. 122 s covers the 1-min work phase and the 1-min
      // short break.
      await _setLifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      sleep(const Duration(seconds: 122));
      await _setLifecycle(tester, [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump(const Duration(milliseconds: 300));

      // Back to focus, one completed work session, and the countdown already
      // ~2 s into the new phase instead of restarting from 01:00.
      expect(find.text('Tempo de foco'), findsOneWidget);
      expect(find.text('Hora de focar novamente!'), findsOneWidget);
      expect(_displayedSeconds(tester), inInclusiveRange(56, 59));
      expect(find.text('Pausar'), findsOneWidget);

      await _tapVisible(tester, find.text('Pausar'));
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'tasks: keyboard "done" adds, list persists and scrolls on a phone',
    (tester) async {
      await _launch(tester);

      await tester.tap(find.widgetWithText(Tab, 'Tarefas'));
      await tester.pumpAndSettle();

      const count = 25;
      for (var i = 0; i < count; i++) {
        await tester.enterText(_todoField, 'Tarefa $i');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('todos')!) as List;
      expect(saved, hasLength(count));
      expect((saved.last as Map)['title'], 'Tarefa ${count - 1}');

      final last = find.text('Tarefa ${count - 1}');
      await tester.scrollUntilVisible(
        last,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);

      // Tap toggles done; completed tasks drop to the end of the list.
      await tester.tap(last);
      await tester.pumpAndSettle();
      final updated = jsonDecode(prefs.getString('todos')!) as List;
      expect((updated.last as Map)['done'], isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Android back button closes Settings', (tester) async {
    await _launch(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.textContaining('Versão'), findsOneWidget);

    // Same path the system back gesture/button takes.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Configurações'), findsNothing);
    expect(find.text('FoxTimer Pomodoro'), findsOneWidget);
  });

  testWidgets('sound preview plays and stops through just_audio', (
    tester,
  ) async {
    await _launch(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.stop_circle), findsOneWidget);
    expect(find.text('Parar'), findsOneWidget);

    await tester.tap(find.text('Parar'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.stop_circle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'in background, phase ends are alarms that post the notification',
    (tester) async {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;

      await _launch(tester);
      expect(
        await android.areNotificationsEnabled(),
        isTrue,
        reason:
            'POST_NOTIFICATIONS not granted. MainActivityTest grants it; '
            'with `flutter test` run first: adb shell pm grant '
            'io.github.romulofer.foxtimer android.permission.POST_NOTIFICATIONS',
      );
      // USE_EXACT_ALARM in the manifest: no prompt, alarms not deferred.
      expect(await android.canScheduleExactNotifications(), isTrue);

      await _setConfig(
        tester,
        work: '1',
        shortBreak: '1',
        longBreak: '1',
        cycles: '2',
      );
      await _tapVisible(tester, find.text('Iniciar'));
      await tester.pump();

      await _setLifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);

      var pending = <PendingNotificationRequest>[];
      for (var i = 0; i < 50 && pending.length < 12; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        pending = await plugin.pendingNotificationRequests();
      }
      expect(pending, hasLength(12));
      pending.sort((a, b) => a.id.compareTo(b.id));
      expect(pending.take(3).map((p) => p.title), const [
        'Pausa curta! Descanse bastante.',
        'Hora de focar novamente!',
        'Pausa longa! Descanse bastante.',
      ]);

      // Let the 1-minute work phase end for real: AlarmManager fires and the
      // notification shows up in the system tray.
      List<ActiveNotification> active = [];
      final deadline = DateTime.now().add(const Duration(seconds: 75));
      while (active.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        active = await plugin.getActiveNotifications();
      }
      expect(active.map((n) => n.title), ['Pausa curta! Descanse bastante.']);
      expect(active.single.channelId, 'cycle_end');

      // Coming back clears both the shown and the still-pending alerts.
      await _setLifecycle(tester, [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(await plugin.pendingNotificationRequests(), isEmpty);
      expect(await plugin.getActiveNotifications(), isEmpty);

      await _tapVisible(tester, find.text('Pausar'));
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
