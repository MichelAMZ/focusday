import 'account_sync_models.dart';

abstract interface class AccountSyncGateway {
  Future<CloudValue<SyncedSettings>?> loadSettings(String userId);
  Future<DateTime> saveSettings(String userId, SyncedSettings settings);
  Future<CloudValue<CloudFocusState>?> loadFocus(String userId);
  Future<DateTime> saveFocus(String userId, CloudFocusState focus);
}
