enum SyncDecision {
  noAction,
  upload,
  download,
  conflict,
  firstSync,
}

SyncDecision decideSync({
  required bool localChanged,
  required DateTime? localLastSyncAt,
  required DateTime? cloudLastSyncAt,
}) {
  if (localLastSyncAt == null) {
    return SyncDecision.firstSync;
  }

  final cloudChanged =
      cloudLastSyncAt != null &&
      cloudLastSyncAt.isAfter(localLastSyncAt);

  if (localChanged && cloudChanged) {
    return SyncDecision.conflict;
  }

  if (localChanged) {
    return SyncDecision.upload;
  }

  if (cloudChanged) {
    return SyncDecision.download;
  }

  return SyncDecision.noAction;
}
