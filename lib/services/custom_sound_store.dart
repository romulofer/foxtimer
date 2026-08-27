import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sound_option.dart';

class CustomSoundStore {
  static const _prefsKey = 'customSounds';

  Future<Directory> _soundsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/custom_sounds');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<SoundOption>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => SoundOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAll(List<SoundOption> sounds) async {
    final prefs = await SharedPreferences.getInstance();
    final list = sounds.map((s) => s.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }

  Future<SoundOption> addFromFile(String sourcePath, String displayLabel) async {
    final dir = await _soundsDir();
    final dotIndex = sourcePath.lastIndexOf('.');
    final ext = dotIndex == -1 ? '' : sourcePath.substring(dotIndex);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final destPath = '${dir.path}/$id$ext';
    await File(sourcePath).copy(destPath);

    final newSound = SoundOption(
      id: id,
      label: displayLabel,
      path: destPath,
      isAsset: false,
      isCustom: true,
    );

    final current = await loadAll();
    current.add(newSound);
    await _saveAll(current);
    return newSound;
  }

  Future<void> remove(String id) async {
    final current = await loadAll();
    final index = current.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final file = File(current[index].path);
    if (await file.exists()) {
      await file.delete();
    }
    current.removeAt(index);
    await _saveAll(current);
  }
}

Future<SoundOption> resolveSoundOption(String id) async {
  for (final sound in bundledSounds) {
    if (sound.id == id) return sound;
  }
  final custom = await CustomSoundStore().loadAll();
  for (final sound in custom) {
    if (sound.id == id) return sound;
  }
  return bundledSounds.first;
}
