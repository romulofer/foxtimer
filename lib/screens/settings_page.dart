import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sound_option.dart';
import '../services/custom_sound_store.dart';

class SettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<void> Function(SoundOption sound, double volume) onPlayTestSound;
  final Future<void> Function() onStopSound;

  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onPlayTestSound,
    required this.onStopSound,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _customSoundStore = CustomSoundStore();

  late ThemeMode _themeMode;
  bool _soundEnabled = true;
  double _soundVolume = 1.0;
  String _selectedSoundId = defaultSoundId;
  List<SoundOption> _customSounds = [];
  String? _playingSoundId;
  bool _importing = false;
  bool _loading = true;

  List<SoundOption> get _allSounds => [...bundledSounds, ..._customSounds];

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
    _loadPreferences();
  }

  @override
  void dispose() {
    widget.onStopSound();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final customSounds = await _customSoundStore.loadAll();
    setState(() {
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _soundVolume = prefs.getDouble('soundVolume') ?? 1.0;
      _selectedSoundId = prefs.getString('selectedSoundId') ?? defaultSoundId;
      _customSounds = customSounds;
      _loading = false;
    });
  }

  Future<void> _saveSoundPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', _soundEnabled);
    await prefs.setDouble('soundVolume', _soundVolume);
    await prefs.setString('selectedSoundId', _selectedSoundId);
  }

  Future<void> _stopSound() async {
    await widget.onStopSound();
    setState(() => _playingSoundId = null);
  }

  Future<void> _playSound(SoundOption sound) async {
    setState(() => _playingSoundId = sound.id);
    await widget.onPlayTestSound(sound, _soundVolume);
  }

  Future<void> _importSound() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'ogg', 'm4a', 'aac'],
      );
      final picked = result?.files.single;
      if (picked == null || picked.path == null) return;

      final label = picked.name.contains('.')
          ? picked.name.substring(0, picked.name.lastIndexOf('.'))
          : picked.name;

      final added = await _customSoundStore.addFromFile(picked.path!, label);
      setState(() {
        _customSounds = [..._customSounds, added];
        _selectedSoundId = added.id;
      });
      await _saveSoundPreferences();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar som: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteCustomSound(SoundOption sound) async {
    if (_playingSoundId == sound.id) {
      await _stopSound();
    }
    await _customSoundStore.remove(sound.id);
    setState(() {
      _customSounds = _customSounds.where((s) => s.id != sound.id).toList();
      if (_selectedSoundId == sound.id) {
        _selectedSoundId = defaultSoundId;
      }
    });
    await _saveSoundPreferences();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tema',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Sistema'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Claro'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Escuro'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {_themeMode},
            onSelectionChanged: (selection) {
              final mode = selection.first;
              setState(() => _themeMode = mode);
              widget.onThemeModeChanged(mode);
            },
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),

          const Text(
            'Som',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Som ao fim do ciclo'),
            value: _soundEnabled,
            onChanged: (value) {
              setState(() => _soundEnabled = value);
              _saveSoundPreferences();
              if (!value) _stopSound();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Volume'),
            subtitle: Slider(
              value: _soundVolume,
              min: 0,
              max: 1,
              divisions: 10,
              label: '${(_soundVolume * 100).round()}%',
              onChanged: _soundEnabled
                  ? (value) => setState(() => _soundVolume = value)
                  : null,
              onChangeEnd: (value) => _saveSoundPreferences(),
            ),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sons disponíveis',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              if (_playingSoundId != null)
                TextButton.icon(
                  onPressed: _stopSound,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Parar'),
                ),
            ],
          ),
          const SizedBox(height: 4),

          for (final sound in _allSounds)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: RadioListTile<String>(
                value: sound.id,
                groupValue: _selectedSoundId,
                onChanged: !_soundEnabled
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedSoundId = value);
                        _saveSoundPreferences();
                      },
                title: Text(sound.label),
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _playingSoundId == sound.id
                            ? Icons.stop_circle
                            : Icons.play_circle_outline,
                        color: colorScheme.primary,
                      ),
                      onPressed: !_soundEnabled
                          ? null
                          : () => _playingSoundId == sound.id
                              ? _stopSound()
                              : _playSound(sound),
                    ),
                    if (sound.isCustom)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteCustomSound(sound),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _importing ? null : _importSound,
            icon: _importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(
              _importing ? 'Importando...' : 'Adicionar som personalizado',
            ),
          ),
        ],
      ),
    );
  }
}
