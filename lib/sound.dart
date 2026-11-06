import 'package:audioplayers/audioplayers.dart';

/// Fully offline SFX engine. All samples are bundled WAV assets, generated to
/// match the original Web Audio synthesis (airy slide whoosh, pitched merge
/// chime per tile value, soft click, win arpeggio).
class Sfx {
  Sfx._();
  static final Sfx I = Sfx._();

  static const _mergeValues = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048];

  bool enabled = true;
  final List<AudioPlayer> _pool =
      List.generate(6, (_) => AudioPlayer(playerId: 'ryzix_$_'));
  int _next = 0;
  bool _warm = false;

  Future<void> init() async {
    if (_warm) return;
    _warm = true;
    for (final p in _pool) {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setPlayerMode(PlayerMode.lowLatency);
    }
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
          .build(),
    );
  }

  Future<void> _play(String file, {double volume = 1.0}) async {
    if (!enabled) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource('sounds/$file'));
    } catch (_) {
      // Never let audio break gameplay.
    }
  }

  void click() => _play('click.wav', volume: 0.7);
  void slide() => _play('slide.wav', volume: 0.85);

  void merge(int val) {
    var pick = _mergeValues.first;
    for (final v in _mergeValues) {
      if (val >= v) pick = v;
    }
    _play('merge_$pick.wav');
  }

  void win() => _play('win.wav');
  void gameOver() => _play('gameover.wav');
}
