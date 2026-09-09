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

  testWidgets('editing a project settles the dialog before rebuilding', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FocusDayApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'Edit' || widget.data == 'Modifier'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Projet modifié');
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'Save' || widget.data == 'Enregistrer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Projet modifié'), findsWidgets);
  });

  testWidgets('editing a task settles the dialog before rebuilding', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FocusDayApp()));
    await tester.pumpAndSettle();

    final taskTile = find.ancestor(
      of: find.byIcon(Icons.chevron_right).first,
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(taskTile);
    await tester.pumpAndSettle();
    await tester.tap(taskTile);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Tâche modifiée');
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'Save' || widget.data == 'Enregistrer'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tâche modifiée'), findsOneWidget);
  });
}
