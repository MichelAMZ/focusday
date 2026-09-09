import 'account_sync_models.dart';
import 'sync_cloud_gateway.dart';

abstract interface class AccountSyncGateway {
  Future<CloudValue<SyncedSettings>?> loadSettings(String userId);
  Future<CloudWriteResult> saveSettings(
    String userId,
    SyncedSettings settings, {
    required int? expectedGeneration,
    bool force = false,
  });
  Future<CloudValue<CloudFocusState>?> loadFocus(String userId);
  Future<CloudWriteResult> saveFocus(
    String userId,
    CloudFocusState focus, {
    required int? expectedGeneration,
    bool force = false,
  });
}
