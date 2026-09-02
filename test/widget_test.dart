import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focusday/app.dart';

void main() {
  testWidgets('FocusDay affiche la page Aujourd’hui', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FocusDayApp()));

    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('Bogoka'), findsWidgets);
  });
}
