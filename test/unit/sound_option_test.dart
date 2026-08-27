import 'package:flutter_test/flutter_test.dart';
import 'package:foxtimer/models/sound_option.dart';

void main() {
  group('SoundOption', () {
    test('toJson/fromJson round trip preserves id/label/path', () {
      const sound = SoundOption(
        id: '123',
        label: 'Sino',
        path: '/home/user/.local/share/foxtimer/custom_sounds/123.wav',
        isAsset: false,
        isCustom: true,
      );

      final json = sound.toJson();
      expect(json, {
        'id': '123',
        'label': 'Sino',
        'path': '/home/user/.local/share/foxtimer/custom_sounds/123.wav',
      });

      final restored = SoundOption.fromJson(json);
      expect(restored.id, sound.id);
      expect(restored.label, sound.label);
      expect(restored.path, sound.path);
      // fromJson always reconstructs a custom, non-asset sound: only custom
      // sounds are ever persisted through this path.
      expect(restored.isAsset, isFalse);
      expect(restored.isCustom, isTrue);
    });
  });

  group('bundledSounds', () {
    test('is non-empty and includes the default sound id', () {
      expect(bundledSounds, isNotEmpty);
      expect(
        bundledSounds.any((s) => s.id == defaultSoundId),
        isTrue,
        reason: 'defaultSoundId must resolve to a real bundled sound',
      );
    });

    test('bundled sounds are assets, never custom', () {
      for (final sound in bundledSounds) {
        expect(sound.isAsset, isTrue);
        expect(sound.isCustom, isFalse);
      }
    });
  });
}
