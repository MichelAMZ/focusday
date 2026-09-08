import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncDomain { settings, focus }

class SyncMutationBus {
  final _controller = StreamController<SyncDomain>.broadcast();

  Stream<SyncDomain> get changes => _controller.stream;
  void notify(SyncDomain domain) => _controller.add(domain);
  Future<void> dispose() => _controller.close();
}

final syncMutationBusProvider = Provider<SyncMutationBus>((ref) {
  final bus = SyncMutationBus();
  ref.onDispose(bus.dispose);
  return bus;
});
