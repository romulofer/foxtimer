import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Fim de uma fase do Pomodoro, com a mensagem mostrada no alerta.
class CycleEnd {
  final DateTime at;
  final String message;

  const CycleEnd(this.at, this.message);
}

/// Alertas de fim de ciclo agendados no sistema (só Android).
///
/// Com o app em segundo plano o Android atrasa ou congela os timers do Dart,
/// então o som de fim de ciclo do próprio app não tocaria. Os alertas ficam
/// agendados no AlarmManager e disparam mesmo com o app congelado, com a
/// tela desligada ou com o processo encerrado.
class CycleNotifications {
  /// Substituível nos testes por uma implementação falsa.
  @visibleForTesting
  static CycleNotifications instance = CycleNotifications();

  static const _soundChannel = AndroidNotificationDetails(
    'cycle_end',
    'Fim do ciclo',
    channelDescription: 'Avisa quando uma fase de foco ou pausa termina.',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    // android/app/src/main/res/raw/town.wav, o mesmo som padrão do app.
    sound: RawResourceAndroidNotificationSound('town'),
  );

  // O som de um canal não pode ser mudado depois de criado, então "som
  // desligado" usa um canal próprio.
  static const _silentChannel = AndroidNotificationDetails(
    'cycle_end_silent',
    'Fim do ciclo (sem som)',
    channelDescription: 'Avisa sem som quando uma fase termina.',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: false,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<bool> _ensureInitialized() async {
    if (!_isSupported) return false;
    if (!_initialized) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_timer'),
        ),
      );
      _initialized = true;
    }
    return true;
  }

  /// Pede a permissão de notificações (Android 13+). Não mostra nada se ela
  /// já foi concedida ou negada de vez.
  Future<void> requestPermission() async {
    if (!await _ensureInitialized()) return;
    await _android?.requestNotificationsPermission();
  }

  /// Substitui os alertas pendentes pelos de [ends] que ainda estão no
  /// futuro. Retorna `false` se nada foi agendado (plataforma sem suporte ou
  /// notificações bloqueadas), caso em que o app deve tocar o som sozinho.
  Future<bool> schedule(List<CycleEnd> ends, {required bool withSound}) async {
    if (!await _ensureInitialized()) return false;
    await _plugin.cancelAll();

    final android = _android!;
    if (await android.areNotificationsEnabled() != true) return false;

    // alarmClock é exato e não sofre o limite de alarmes do modo Doze, que
    // atrasaria pausas curtas. Sem a permissão de alarme exato, cai para o
    // modo inexato em vez de não avisar.
    final mode = await android.canScheduleExactNotifications() == true
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final details = NotificationDetails(
      android: withSound ? _soundChannel : _silentChannel,
    );

    final now = DateTime.now();
    var id = 0;
    for (final end in ends) {
      if (!end.at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: id++,
        title: end.message,
        body: 'FoxTimer',
        scheduledDate: tz.TZDateTime.from(end.at, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: mode,
      );
    }
    return id > 0;
  }

  /// Remove alertas pendentes e já exibidos.
  Future<void> cancelAll() async {
    if (!await _ensureInitialized()) return;
    await _plugin.cancelAll();
  }
}
