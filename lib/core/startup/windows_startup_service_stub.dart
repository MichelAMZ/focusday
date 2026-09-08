class WindowsStartupService {
  const WindowsStartupService();

  Future<void> initialize() async {}

  Future<bool> isEnabled() async => false;

  Future<void> setEnabled(bool enabled) async {}
}
