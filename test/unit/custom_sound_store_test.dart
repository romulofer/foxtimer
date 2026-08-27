import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foxtimer/models/sound_option.dart';
import 'package:foxtimer/services/custom_sound_store.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('foxtimer_sound_store_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CustomSoundStore', () {
    test('loadAll returns empty list when nothing was imported', () async {
      final store = CustomSoundStore();
      expect(await store.loadAll(), isEmpty);
    });

    test('addFromFile copies the file and persists metadata', () async {
      final sourceFile = File('${tempDir.path}/source.wav');
      await sourceFile.writeAsBytes([1, 2, 3, 4]);

      final store = CustomSoundStore();
      final added = await store.addFromFile(sourceFile.path, 'Meu som');

      expect(added.label, 'Meu som');
      expect(added.isAsset, isFalse);
      expect(added.isCustom, isTrue);
      expect(added.path, isNot(sourceFile.path));
      expect(await File(added.path).exists(), isTrue);
      expect(await File(added.path).readAsBytes(), [1, 2, 3, 4]);

      final all = await store.loadAll();
      expect(all, hasLength(1));
      expect(all.single.id, added.id);
      expect(all.single.path, added.path);
    });

    test('addFromFile preserves the original file extension', () async {
      final sourceFile = File('${tempDir.path}/source.mp3');
      await sourceFile.writeAsBytes([9]);

      final added = await CustomSoundStore().addFromFile(
        sourceFile.path,
        'Trilha',
      );

      expect(added.path.endsWith('.mp3'), isTrue);
    });

    test('remove deletes both the file and the persisted entry', () async {
      final sourceFile = File('${tempDir.path}/source.wav');
      await sourceFile.writeAsBytes([1]);

      final store = CustomSoundStore();
      final added = await store.addFromFile(sourceFile.path, 'Removível');
      expect(await File(added.path).exists(), isTrue);

      await store.remove(added.id);

      expect(await File(added.path).exists(), isFalse);
      expect(await store.loadAll(), isEmpty);
    });

    test('remove is a no-op for an unknown id', () async {
      final store = CustomSoundStore();
      await store.remove('does-not-exist');
      expect(await store.loadAll(), isEmpty);
    });

    test('multiple imports accumulate independently', () async {
      final store = CustomSoundStore();
      final fileA = File('${tempDir.path}/a.wav')..writeAsBytesSync([1]);
      final fileB = File('${tempDir.path}/b.wav')..writeAsBytesSync([2]);

      final addedA = await store.addFromFile(fileA.path, 'A');
      final addedB = await store.addFromFile(fileB.path, 'B');

      final all = await store.loadAll();
      expect(all.map((s) => s.id), containsAll([addedA.id, addedB.id]));
      expect(all, hasLength(2));
    });
  });

  group('resolveSoundOption', () {
    test('resolves a bundled sound id without touching custom storage', () async {
      final resolved = await resolveSoundOption(defaultSoundId);
      expect(resolved.id, defaultSoundId);
      expect(resolved.isAsset, isTrue);
    });

    test('resolves a previously imported custom sound id', () async {
      final sourceFile = File('${tempDir.path}/custom.wav');
      await sourceFile.writeAsBytes([7]);
      final added = await CustomSoundStore().addFromFile(
        sourceFile.path,
        'Personalizado',
      );

      final resolved = await resolveSoundOption(added.id);
      expect(resolved.id, added.id);
      expect(resolved.path, added.path);
      expect(resolved.isAsset, isFalse);
    });

    test('falls back to the first bundled sound for an unknown id', () async {
      final resolved = await resolveSoundOption('nonexistent-id');
      expect(resolved.id, bundledSounds.first.id);
    });
  });
}
