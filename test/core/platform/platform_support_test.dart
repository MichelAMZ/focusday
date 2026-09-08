import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/core/platform/platform_support.dart';

void main() {
  group('isWindowsDesktop', () {
    test('returns false on Web even when the target platform is Windows', () {
      expect(
        isWindowsDesktop(isWeb: true, platform: TargetPlatform.windows),
        isFalse,
      );
    });

    test('returns true for a native Windows target', () {
      expect(
        isWindowsDesktop(isWeb: false, platform: TargetPlatform.windows),
        isTrue,
      );
    });

    test('returns false for another native desktop target', () {
      expect(
        isWindowsDesktop(isWeb: false, platform: TargetPlatform.linux),
        isFalse,
      );
    });
  });
}
