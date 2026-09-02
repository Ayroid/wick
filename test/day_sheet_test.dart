import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/day_sheet.dart';
import 'package:habit_tracker/detail.dart';
import 'package:habit_tracker/edit_sheet.dart';
import 'package:habit_tracker/grid.dart';
import 'package:habit_tracker/home.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Backfilling a past day moved to the detail screen with the redesign: the
  // dashboard card's grid cells are display-only there, far too small to hit.
  Future<HabitStore> water(WidgetTester tester) async {
    final store = HabitStore();
    await store.load();
    final h = store.add('Water', target: 8);
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: HabitDetailScreen(store: store, habit: h),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  /// Today's cell — the last interactive one in the contribution grid.
  Finder todayCell() => find
      .descendant(
        of: find.byType(ContributionGrid),
        matching: find.byType(GestureDetector),
      )
      .last;

  testWidgets('tapping a grid cell still fills the whole day', (tester) async {
    final store = await water(tester);
    await tester.tap(todayCell());
    await tester.pumpAndSettle();
    expect(store.habits.single.amountOn(today()), 8);
  });

  testWidgets('holding a grid cell sets an exact amount', (tester) async {
    final store = await water(tester);
    await tester.longPress(todayCell());
    await tester.pumpAndSettle();

    expect(find.text('0 of 8'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.descendant(
          of: find.byType(AmountStepper), matching: find.byIcon(Icons.add)));
      await tester.pump();
    }
    expect(find.text('5 of 8'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final h = store.habits.single;
    expect(h.amountOn(today()), 5);
    expect(h.isDoneOn(today()), isFalse); // partial, not done
  });

  testWidgets('the amount stepper is absent for a plain check-off',
      (tester) async {
    final store = HabitStore();
    await store.load();
    final h = store.add('Read');
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDaySheet(context, store, h, today()),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Amount'), findsNothing);
    // The note field is the sheet — its hint stands in for the old heading.
    expect(find.text('What went well? What got in the way?'), findsOneWidget);
  });

  testWidgets('checking a habit off says nothing at all', (tester) async {
    final store = HabitStore();
    await store.load();
    store.add('Run');
    store.add('Stretch'); // a second, so this isn't the all-done celebration
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: HomeScreen(store: store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HabitMark).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // a toast would be in

    expect(store.habits.first.doneToday, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a note is written by holding the day itself', (tester) async {
    // The path the check-off toast used to short-cut to. It is the only one
    // now, so it is the one worth a test.
    final store = HabitStore();
    await store.load();
    store.setCompactLayout(true); // where the dashboard's cells are tappable
    store.add('Run');

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: HomeScreen(store: store),
    ));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(GridCell).last); // today
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Felt unusually easy.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.habits.first.noteOn(today()), 'Felt unusually easy.');
  });

  testWidgets('the celebration keeps the note offer', (tester) async {
    final store = HabitStore();
    await store.load();
    store.add('Run'); // the only habit, so checking it finishes the day

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: HomeScreen(store: store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HabitMark).first);
    await tester.pumpAndSettle();
    expect(find.text('All done today!'), findsOneWidget);

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Finished everything.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.habits.single.noteOn(today()), 'Finished everything.');
  });
}
