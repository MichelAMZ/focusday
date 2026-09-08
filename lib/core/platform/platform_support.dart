import 'package:flutter/foundation.dart';

bool isWindowsDesktop({bool? isWeb, TargetPlatform? platform}) {
  return !(isWeb ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.windows;
}
