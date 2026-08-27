import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sound_option.dart';
import '../models/todo_item.dart';
import '../services/custom_sound_store.dart';
import '../widgets/config_section.dart';
import '../widgets/todo_section.dart';
import 'settings_page.dart';

class PomodoroPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const PomodoroPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Configurações padrão (em minutos)
  int _workMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  int _cyclesBeforeLongBreak = 4;

  // Estado interno do Pomodoro
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isWorkTime = true;
  bool _isLongBreak = false;
  int _completedWorkSessions = 0;

  Timer? _timer;

  // Player de som
  AudioPlayer? _audioPlayer;
  Player? _mediaKitPlayer;
  bool _soundEnabled = true;
  double _soundVolume = 1.0;
  String _selectedSoundId = defaultSoundId;

  // To-do list
  final TextEditingController _todoController = TextEditingController();
  final FocusNode _todoFocusNode = FocusNode();
  List<TodoItem> _todos = [];

  // Controllers das configurações
  late final TextEditingController _workMinutesCtrl;
  late final TextEditingController _shortBreakMinutesCtrl;
  late final TextEditingController _longBreakMinutesCtrl;
  late final TextEditingController _cyclesBeforeLongBreakCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _remainingSeconds = _workMinutes * 60;

    // Initialize platform-specific audio player
    if (Platform.isLinux) {
      _mediaKitPlayer = Player();
    } else {
      _audioPlayer = AudioPlayer();
    }

    _workMinutesCtrl = TextEditingController(text: _workMinutes.toString());
    _shortBreakMinutesCtrl = TextEditingController(
      text: _shortBreakMinutes.toString(),
    );
    _longBreakMinutesCtrl = TextEditingController(
      text: _longBreakMinutes.toString(),
    );
    _cyclesBeforeLongBreakCtrl = TextEditingController(
      text: _cyclesBeforeLongBreak.toString(),
    );

    _loadPreferencesAndTodos().then((_) => _initSound());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    _audioPlayer?.dispose();
    _mediaKitPlayer?.dispose();
    _todoController.dispose();
    _workMinutesCtrl.dispose();
    _shortBreakMinutesCtrl.dispose();
    _longBreakMinutesCtrl.dispose();
    _cyclesBeforeLongBreakCtrl.dispose();
    _todoFocusNode.dispose();
    super.dispose();
  }

  // ==============================
  // ÁUDIO
  // ==============================

  Future<void> _openSound(SoundOption sound, double volume) async {
    if (Platform.isLinux) {
      final uri = sound.isAsset ? 'asset:///${sound.path}' : sound.path;
      await _mediaKitPlayer?.open(Media(uri), play: false);
      await _mediaKitPlayer?.setVolume(volume * 100);
    } else {
      if (sound.isAsset) {
        await _audioPlayer?.setAsset(sound.path);
      } else {
        await _audioPlayer?.setFilePath(sound.path);
      }
      await _audioPlayer?.setVolume(volume);
    }
  }

  Future<void> _initSound() async {
    try {
      final sound = await resolveSoundOption(_selectedSoundId);
      await _openSound(sound, _soundVolume);
      debugPrint('Áudio carregado com sucesso');
    } catch (e) {
      debugPrint('Erro ao carregar áudio: $e');
    }
  }

  // Reabre a mídia a partir das preferências salvas sempre antes de tocar.
  // Não confia no player já ter uma mídia carregada: um `stop()` anterior,
  // uma troca de som nas Configurações ou uma falha transitória de
  // carregamento não podem deixar o som de fim de ciclo silenciosamente
  // sem tocar.
  Future<void> _playEndSound() async {
    if (!_soundEnabled) return;
    try {
      final sound = await resolveSoundOption(_selectedSoundId);
      await _openSound(sound, _soundVolume);
      if (Platform.isLinux) {
        await _mediaKitPlayer?.play();
      } else {
        await _audioPlayer?.play();
      }
    } catch (e) {
      debugPrint('Erro ao tocar áudio: $e');
    }
  }

  // pause()+seek(0) em vez de stop(): o stop() do media_kit roda
  // playlist-clear e descarrega a mídia carregada, então uma chamada
  // concorrente com o reload de som (ex.: SettingsPage.dispose() disparando
  // isso sem esperar, ao mesmo tempo que _loadSoundPreferencesAndReinit
  // reabre o som) podia deixar o próximo fim de ciclo sem áudio.
  Future<void> _stopSound() async {
    try {
      if (Platform.isLinux) {
        await _mediaKitPlayer?.pause();
        await _mediaKitPlayer?.seek(Duration.zero);
      } else {
        await _audioPlayer?.pause();
        await _audioPlayer?.seek(Duration.zero);
      }
    } catch (e) {
      debugPrint('Erro ao parar áudio: $e');
    }
  }

  Future<void> _playTestSound(SoundOption sound, double volume) async {
    try {
      await _openSound(sound, volume);
      if (Platform.isLinux) {
        await _mediaKitPlayer?.play();
      } else {
        await _audioPlayer?.play();
      }
    } catch (e) {
      debugPrint('Erro ao testar áudio: $e');
    }
  }

  // ==============================
  // LOAD / SAVE CONFIGS + TASKS
  // ==============================

  Future<void> _loadPreferencesAndTodos() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _workMinutes = prefs.getInt('workMinutes') ?? 25;
      _shortBreakMinutes = prefs.getInt('shortBreakMinutes') ?? 5;
      _longBreakMinutes = prefs.getInt('longBreakMinutes') ?? 15;
      _cyclesBeforeLongBreak = prefs.getInt('cyclesBeforeLongBreak') ?? 4;

      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _soundVolume = prefs.getDouble('soundVolume') ?? 1.0;
      _selectedSoundId = prefs.getString('selectedSoundId') ?? defaultSoundId;

      _workMinutesCtrl.text = _workMinutes.toString();
      _shortBreakMinutesCtrl.text = _shortBreakMinutes.toString();
      _longBreakMinutesCtrl.text = _longBreakMinutes.toString();
      _cyclesBeforeLongBreakCtrl.text = _cyclesBeforeLongBreak.toString();

      _applyDurationsToCurrentPhase();

      final todosString = prefs.getString('todos');
      if (todosString != null) {
        final List decoded = jsonDecode(todosString) as List;
        _todos = decoded
            .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _todos = [];
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('workMinutes', _workMinutes);
    await prefs.setInt('shortBreakMinutes', _shortBreakMinutes);
    await prefs.setInt('longBreakMinutes', _longBreakMinutes);
    await prefs.setInt('cyclesBeforeLongBreak', _cyclesBeforeLongBreak);
  }

  Future<void> _loadSoundPreferencesAndReinit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _soundVolume = prefs.getDouble('soundVolume') ?? 1.0;
      _selectedSoundId = prefs.getString('selectedSoundId') ?? defaultSoundId;
    });
    await _initSound();
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final listMap = _todos.map((t) => t.toJson()).toList();
    await prefs.setString('todos', jsonEncode(listMap));
  }

  void _applyDurationsToCurrentPhase() {
    if (_isWorkTime) {
      _remainingSeconds = _workMinutes * 60;
    } else if (_isLongBreak) {
      _remainingSeconds = _longBreakMinutes * 60;
    } else {
      _remainingSeconds = _shortBreakMinutes * 60;
    }
  }

  Future<void> _changeConfig({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? cyclesBeforeLongBreak,
  }) async {
    if (_isRunning) {
      return;
    }

    setState(() {
      if (workMinutes != null) {
        _workMinutes = workMinutes;
        _workMinutesCtrl.text = _workMinutes.toString();
      }
      if (shortBreakMinutes != null) {
        _shortBreakMinutes = shortBreakMinutes;
        _shortBreakMinutesCtrl.text = _shortBreakMinutes.toString();
      }
      if (longBreakMinutes != null) {
        _longBreakMinutes = longBreakMinutes;
        _longBreakMinutesCtrl.text = _longBreakMinutes.toString();
      }
      if (cyclesBeforeLongBreak != null) {
        _cyclesBeforeLongBreak = cyclesBeforeLongBreak;
        _cyclesBeforeLongBreakCtrl.text = _cyclesBeforeLongBreak.toString();
      }
      _applyDurationsToCurrentPhase();
    });

    await _savePreferences();
  }

  void _onApplyPressed() {
    if (_isRunning) return;

    final work = int.tryParse(_workMinutesCtrl.text.trim());
    final shortB = int.tryParse(_shortBreakMinutesCtrl.text.trim());
    final longB = int.tryParse(_longBreakMinutesCtrl.text.trim());
    final cycles = int.tryParse(_cyclesBeforeLongBreakCtrl.text.trim());

    if (work == null ||
        shortB == null ||
        longB == null ||
        cycles == null ||
        work <= 0 ||
        shortB <= 0 ||
        longB <= 0 ||
        cycles <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, insira apenas números válidos (maiores que zero).',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    _changeConfig(
      workMinutes: work,
      shortBreakMinutes: shortB,
      longBreakMinutes: longB,
      cyclesBeforeLongBreak: cycles,
    );
  }

  // ==============================
  // TIMER
  // ==============================

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _onTimerFinished();
      }
    });

    setState(() => _isRunning = true);
  }

  void _startPauseTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      _startTimer();
    }
  }

  void _onTimerFinished() async {
    await _playEndSound();

    String message = ''; // ← CORREÇÃO

    setState(() {
      if (_isWorkTime) {
        _completedWorkSessions++;

        if (_completedWorkSessions % _cyclesBeforeLongBreak == 0) {
          _isWorkTime = false;
          _isLongBreak = true;
          _remainingSeconds = _longBreakMinutes * 60;
          message = 'Pausa longa! Descanse bastante.';
        } else {
          _isWorkTime = false;
          _isLongBreak = false;
          _remainingSeconds = _shortBreakMinutes * 60;
          message = 'Pausa curta! Descanse bastante.';
        }
      } else {
        // Terminou pausa → volta ao foco
        _isWorkTime = true;
        _isLongBreak = false;
        _remainingSeconds = _workMinutes * 60;
        message = 'Hora de focar novamente!';
      }
    });

    // Inicia automaticamente novo ciclo
    _startTimer();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: 'Parar som', onPressed: _stopSound),
        ),
      );
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isWorkTime = true;
      _isLongBreak = false;
      _remainingSeconds = _workMinutes * 60;
      _completedWorkSessions = 0;
    });
  }

  // ==============================
  // TO-DO LIST
  // ==============================

  Future<void> _addTodo() async {
    final text = _todoController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _todos.add(TodoItem(title: text));
      _todoController.clear();
      _todoFocusNode.requestFocus();
    });

    await _saveTodos();
  }

  Future<void> _toggleTodoDone(int index, bool? value) async {
    setState(() {
      _todos[index].done = value ?? false;
    });
    await _saveTodos();
  }

  Future<void> _removeTodo(int index) async {
    setState(() {
      _todos.removeAt(index);
    });
    await _saveTodos();
  }

  // ==============================
  // UI
  // ==============================

  int get _totalSecondsForPhase {
    if (_isWorkTime) return _workMinutes * 60;
    if (_isLongBreak) return _longBreakMinutes * 60;
    return _shortBreakMinutes * 60;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String modeText;
    IconData modeIcon;
    Color modeColor;
    if (_isWorkTime) {
      modeText = 'Tempo de foco';
      modeIcon = Icons.local_fire_department;
      modeColor = colorScheme.primary;
    } else if (_isLongBreak) {
      modeText = 'Pausa longa';
      modeIcon = Icons.weekend;
      modeColor = colorScheme.secondary;
    } else {
      modeText = 'Pausa curta';
      modeIcon = Icons.coffee;
      modeColor = colorScheme.secondary;
    }

    final total = _totalSecondsForPhase;
    final progress = total == 0 ? 0.0 : 1 - (_remainingSeconds / total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoxTimer Pomodoro'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: _openSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.timer), text: 'Timer'),
            Tab(icon: Icon(Icons.checklist), text: 'Tarefas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConfigSection(
                  isRunning: _isRunning,
                  workMinutesCtrl: _workMinutesCtrl,
                  shortBreakMinutesCtrl: _shortBreakMinutesCtrl,
                  longBreakMinutesCtrl: _longBreakMinutesCtrl,
                  cyclesBeforeLongBreakCtrl: _cyclesBeforeLongBreakCtrl,
                  onApply: _onApplyPressed,
                ),
                const SizedBox(height: 24),

                // Timer / Pomodoro
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: modeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(modeIcon, size: 18, color: modeColor),
                            const SizedBox(width: 8),
                            Text(
                              modeText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: modeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 240,
                              height: 240,
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: 10,
                                strokeCap: StrokeCap.round,
                                backgroundColor: colorScheme.onSurface.withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation(modeColor),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(_remainingSeconds),
                                  style: const TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                Text(
                                  _isRunning ? 'em andamento' : 'pausado',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_cyclesBeforeLongBreak, (i) {
                          final filled =
                              i < (_completedWorkSessions % _cyclesBeforeLongBreak) ||
                              (_completedWorkSessions != 0 &&
                                  _completedWorkSessions % _cyclesBeforeLongBreak == 0 &&
                                  i < _cyclesBeforeLongBreak);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.outlined(
                            iconSize: 22,
                            padding: const EdgeInsets.all(14),
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Reiniciar',
                            onPressed: _resetTimer,
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            icon: Icon(
                              _isRunning ? Icons.pause : Icons.play_arrow,
                            ),
                            onPressed: _startPauseTimer,
                            label: Text(_isRunning ? 'Pausar' : 'Iniciar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: TodoSection(
              todos: _todos,
              todoController: _todoController,
              todoFocusNode: _todoFocusNode,
              onAddTodo: _addTodo,
              onToggleTodoDone: _toggleTodoDone,
              onRemoveTodo: _removeTodo,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          onPlayTestSound: _playTestSound,
          onStopSound: _stopSound,
        ),
      ),
    );
    await _loadSoundPreferencesAndReinit();
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
