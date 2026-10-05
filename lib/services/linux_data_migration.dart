import 'dart:io';

import 'package:flutter/foundation.dart';

const _oldId = 'com.example.foxtimer';
const _newId = 'io.github.romulofer.foxtimer';

/// No Linux os dados do app (preferências, tarefas, sons personalizados)
/// ficam em `$XDG_DATA_HOME/<APPLICATION_ID>`. O ID mudou de
/// com.example.foxtimer para io.github.romulofer.foxtimer na 1.5.1, então o
/// diretório antigo é movido para o novo uma única vez.
Future<void> migrateLinuxDataDir({String? dataHome}) async {
  dataHome ??= _xdgDataHome();
  if (dataHome == null) return;

  final oldDir = Directory('$dataHome/$_oldId');
  final newDir = Directory('$dataHome/$_newId');
  if (!oldDir.existsSync() || newDir.existsSync()) return;

  try {
    await oldDir.rename(newDir.path);
    // Os sons personalizados são salvos com caminho absoluto nas preferências.
    final prefs = File('${newDir.path}/shared_preferences.json');
    if (prefs.existsSync()) {
      final text = await prefs.readAsString();
      await prefs.writeAsString(text.replaceAll(oldDir.path, newDir.path));
    }
  } catch (e) {
    debugPrint('Erro ao migrar dados de $_oldId: $e');
  }
}

String? _xdgDataHome() {
  final xdg = Platform.environment['XDG_DATA_HOME'];
  if (xdg != null && xdg.isNotEmpty) return xdg;
  final home = Platform.environment['HOME'];
  return home == null ? null : '$home/.local/share';
}
