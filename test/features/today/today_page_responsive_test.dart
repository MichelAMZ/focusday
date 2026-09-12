import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focusday/app.dart';

void main() {
  Future<void> pumpFocusDayAtSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: FocusDayApp()));

    await tester.pumpAndSettle();
  }

  final sizes = <Size>[
    const Size(720, 520),
    const Size(900, 600),
    const Size(1200, 760),
    const Size(1600, 900),
  ];

  for (final size in sizes) {
    testWidgets('Today page has no layout exception at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpFocusDayAtSize(tester, size);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Today' || widget.data == 'Aujourd’hui'),
        ),
        findsOneWidget,
      );

      expect(find.text('Bogoka'), findsWidgets);

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Une exception Flutter/RenderFlex a été détectée '
            'à ${size.width.toInt()}x${size.height.toInt()}.',
      );
    });
  }
}
