import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxtimer/widgets/config_section.dart';

class _Controllers {
  final work = TextEditingController(text: '25');
  final shortBreak = TextEditingController(text: '5');
  final longBreak = TextEditingController(text: '15');
  final cycles = TextEditingController(text: '4');
}

Widget _build(_Controllers c, {required bool isRunning, VoidCallback? onApply}) {
  return MaterialApp(
    home: Scaffold(
      body: ConfigSection(
        isRunning: isRunning,
        workMinutesCtrl: c.work,
        shortBreakMinutesCtrl: c.shortBreak,
        longBreakMinutesCtrl: c.longBreak,
        cyclesBeforeLongBreakCtrl: c.cycles,
        onApply: onApply ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('fields are editable and Apply enabled when not running', (
    tester,
  ) async {
    final c = _Controllers();
    var applied = false;

    await tester.pumpWidget(_build(c, isRunning: false, onApply: () => applied = true));

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, hasLength(4));
    expect(fields.every((f) => f.enabled != false), isTrue);

    await tester.tap(find.text('Aplicar'));
    await tester.pump();
    expect(applied, isTrue);
  });

  testWidgets('fields and Apply button are disabled while running', (
    tester,
  ) async {
    final c = _Controllers();
    var applied = false;

    await tester.pumpWidget(_build(c, isRunning: true, onApply: () => applied = true));

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.every((f) => f.enabled != true), isTrue);

    expect(
      find.text('Bloqueado enquanto o timer está em execução.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Aplicar'));
    await tester.pump();
    expect(applied, isFalse);
  });
}
