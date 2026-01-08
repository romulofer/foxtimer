import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/pomodoro_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize MediaKit on Linux
  if (Platform.isLinux) {
    MediaKit.ensureInitialized();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoxTimer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const PomodoroPage(),
    );
  }
}
