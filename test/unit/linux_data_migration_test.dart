import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foxtimer/services/linux_data_migration.dart';

void main() {
  late Directory dataHome;
  late Directory oldDir;
  late Directory newDir;

  setUp(() {
    dataHome = Directory.systemTemp.createTempSync('foxtimer_xdg_');
    oldDir = Directory('${dataHome.path}/com.example.foxtimer');
    newDir = Directory('${dataHome.path}/io.github.romulofer.foxtimer');
  });
  tearDown(() => dataHome.deleteSync(recursive: true));

  test('moves the old data dir and rewrites custom sound paths', () async {
    File('${oldDir.path}/custom_sounds/1.flac').createSync(recursive: true);
    final sounds = jsonEncode([
      {
        'id': '1',
        'label': 'Sino',
        'path': '${oldDir.path}/custom_sounds/1.flac',
      },
    ]);
    File('${oldDir.path}/shared_preferences.json').writeAsStringSync(
      jsonEncode({'flutter.customSounds': sounds, 'flutter.workMinutes': 30}),
    );

    await migrateLinuxDataDir(dataHome: dataHome.path);

    expect(oldDir.existsSync(), isFalse);
    expect(File('${newDir.path}/custom_sounds/1.flac').existsSync(), isTrue);
    final prefs =
        jsonDecode(
              File('${newDir.path}/shared_preferences.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(prefs['flutter.workMinutes'], 30);
    final migrated =
        jsonDecode(prefs['flutter.customSounds'] as String) as List;
    expect(
      (migrated.single as Map)['path'],
      '${newDir.path}/custom_sounds/1.flac',
    );
    expect(
      File((migrated.single as Map)['path'] as String).existsSync(),
      isTrue,
    );
  });

  test('leaves an existing new data dir untouched', () async {
    File('${oldDir.path}/shared_preferences.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"old":true}');
    File('${newDir.path}/shared_preferences.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"new":true}');

    await migrateLinuxDataDir(dataHome: dataHome.path);

    expect(oldDir.existsSync(), isTrue);
    expect(
      File('${newDir.path}/shared_preferences.json').readAsStringSync(),
      '{"new":true}',
    );
  });

  test('does nothing on a fresh install', () async {
    await migrateLinuxDataDir(dataHome: dataHome.path);
    expect(newDir.existsSync(), isFalse);
  });
}
