import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/templates.dart';
import 'package:habit_tracker/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('picking starter habits closes the screen', (tester) async {
    final store = HabitStore();
    await store.load();
    var done = false;

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => openStarterTemplates(context, store,
                  firstRun: true, onDone: () => done = true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final first = starterGroups.values.first.first;
    await tester.scrollUntilVisible(find.text(first.name), 120);
    await tester.tap(find.text(first.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 habit'));
    await tester.pumpAndSettle();

    // The route is gone and the caller's follow-up ran.
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Add 1 habit'), findsNothing);
    expect(done, isTrue);
    expect(store.habits.single.name, first.name);
  });
}
