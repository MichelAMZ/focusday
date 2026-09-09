import 'package:flutter/material.dart';

/// Shows a Material dialog and completes only after its overlay is removed.
Future<T?> showSettledDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    themes: themes,
    barrierColor:
        DialogTheme.of(context).barrierColor ??
        Theme.of(context).dialogTheme.barrierColor ??
        Colors.black54,
    barrierDismissible: true,
  );

  final result = await navigator.push<T>(route);
  await route.completed;
  return result;
}
