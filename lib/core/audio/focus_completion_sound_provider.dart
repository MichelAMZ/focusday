import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'focus_completion_sound_service.dart';

final focusCompletionSoundProvider = Provider<FocusCompletionSoundService>((
  ref,
) {
  final service = FocusCompletionSoundService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
