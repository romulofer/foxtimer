import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foxtimer/main.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      MediaKit.ensureInitialized();
    }
  });

  testWidgets('FoxTimer starts on the timer tab with the default duration', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('FoxTimer Pomodoro'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
  });
}
