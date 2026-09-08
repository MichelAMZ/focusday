abstract class SyncMetadataReader {
  Future<DateTime?> loadLastSyncAt(String userId);
}
