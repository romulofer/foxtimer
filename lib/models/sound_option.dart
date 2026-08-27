class SoundOption {
  final String id;
  final String label;

  /// Flutter asset path (isAsset=true) or absolute file path (isAsset=false).
  final String path;
  final bool isAsset;
  final bool isCustom;

  const SoundOption({
    required this.id,
    required this.label,
    required this.path,
    required this.isAsset,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'path': path};

  factory SoundOption.fromJson(Map<String, dynamic> json) => SoundOption(
    id: json['id'] as String,
    label: json['label'] as String,
    path: json['path'] as String,
    isAsset: false,
    isCustom: true,
  );
}

const List<SoundOption> bundledSounds = [
  SoundOption(
    id: 'town',
    label: 'Cidade (padrão)',
    path: 'assets/sounds/town.wav',
    isAsset: true,
  ),
];

const String defaultSoundId = 'town';
