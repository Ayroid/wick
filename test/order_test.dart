import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/home.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('checking a habit off leaves it where it is', (tester) async {
    final store = HabitStore();
    await store.load();
    store.add('Alpha');
    store.add('Beta');

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: HomeScreen(store: store),
    ));
    await tester.pumpAndSettle();
    expect(store.visible.map((h) => h.name), ['Alpha', 'Beta']);

    // The mark is the check-off target; the name opens the detail screen.
    await tester.tap(find.descendant(
        of: find.ancestor(
            of: find.text('Alpha'), matching: find.byType(HabitTile)),
        matching: find.byType(HabitMark)));
    await tester.pumpAndSettle();

    expect(store.habits.first.doneToday, isTrue);
    expect(store.visible.map((h) => h.name), ['Alpha', 'Beta']);
  });
}
