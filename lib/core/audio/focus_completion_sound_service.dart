import 'package:audioplayers/audioplayers.dart';

class FocusCompletionSoundService {
  FocusCompletionSoundService() : _player = AudioPlayer();

  final AudioPlayer _player;

  Future<void> play() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/focus_complete.wav'), volume: 0.8);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
