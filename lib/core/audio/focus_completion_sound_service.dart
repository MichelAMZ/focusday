import 'package:audioplayers/audioplayers.dart';

abstract interface class FocusCompletionSoundPlayer {
  Future<void> play();
  Future<void> dispose();
}

class FocusCompletionSoundService implements FocusCompletionSoundPlayer {
  FocusCompletionSoundService() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/focus_complete.wav'), volume: 0.8);
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}
