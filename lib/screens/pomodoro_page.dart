import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo_item.dart';
import '../widgets/config_section.dart';
import '../widgets/todo_section.dart';

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
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
  bool _soundReady = false;

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

    _loadPreferencesAndTodos();
    _initSound();
  }

  @override
  void dispose() {
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

  Future<void> _initSound() async {
    try {
      if (Platform.isLinux) {
        await _mediaKitPlayer?.open(
          Media('asset:///assets/sounds/town.wav'),
          play: false,
        );
      } else {
        await _audioPlayer?.setAsset('assets/sounds/town.wav');
      }
      _soundReady = true;
      debugPrint('Áudio carregado com sucesso');
    } catch (e) {
      debugPrint('Erro ao carregar áudio: $e');
      _soundReady = false;
    }
  }

  Future<void> _playEndSound() async {
    if (!_soundReady) return;
    try {
      if (Platform.isLinux) {
        await _mediaKitPlayer?.seek(Duration.zero);
        await _mediaKitPlayer?.play();
      } else {
        await _audioPlayer?.seek(Duration.zero);
        await _audioPlayer?.play();
      }
    } catch (e) {
      debugPrint('Erro ao tocar áudio: $e');
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
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
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

  @override
  Widget build(BuildContext context) {
    String modeText;
    if (_isWorkTime) {
      modeText = 'Tempo de foco';
    } else if (_isLongBreak) {
      modeText = 'Pausa longa';
    } else {
      modeText = 'Pausa curta';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('FoxTimer Pomodoro'), centerTitle: true),
      body: SingleChildScrollView(
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
                  Text(
                    modeText,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: const TextStyle(
                      fontSize: 70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ciclos de foco concluídos: $_completedWorkSessions',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    onPressed: _startPauseTimer,
                    label: Text(_isRunning ? 'Pausar' : 'Iniciar'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    onPressed: _resetTimer,
                    label: const Text('Reiniciar'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 12),

            TodoSection(
              todos: _todos,
              todoController: _todoController,
              todoFocusNode: _todoFocusNode,
              onAddTodo: _addTodo,
              onToggleTodoDone: _toggleTodoDone,
              onRemoveTodo: _removeTodo,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
