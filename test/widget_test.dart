import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focusday/app.dart';

void main() {
  testWidgets('FocusDay displays the Today page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FocusDayApp()));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'Today' || widget.data == 'Aujourd’hui'),
      ),
      findsOneWidget,
    );
    expect(find.text('Bogoka'), findsWidgets);
  });
}
