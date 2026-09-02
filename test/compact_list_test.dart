import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/compact_list.dart';
import 'package:habit_tracker/grid.dart';
import 'package:habit_tracker/home.dart';
import 'package:habit_tracker/main.dart';
import 'package:habit_tracker/page_bar.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<HabitStore> seeded() async {
    final store = HabitStore();
    await store.load();
    store.setCompactLayout(true);
    store.add('Read');
    store.add('Run');
    return store;
  }

  Widget app(Widget child) =>
      MaterialApp(theme: appTheme(dark: false), home: child);

  test('the window is n days ending today, oldest first', () {
    expect(lastDays(1), [today()]);
    expect(lastDays(5), [
      shiftDays(today(), -4),
      shiftDays(today(), -3),
      shiftDays(today(), -2),
      shiftDays(today(), -1),
      today(),
    ]);
  });

  test('a single-day window names one date, not a range', () {
    expect(rangeLabel(lastDays(1)).contains('—'), isFalse);
    expect(rangeLabel(lastDays(3)).contains('—'), isTrue);
  });

  test('the day count is clamped, whatever the stored value says', () async {
    SharedPreferences.setMockInitialValues({'compactDays': 99});
    final store = HabitStore();
    await store.load();
    expect(store.compactDays, 7);

    store.setCompactDays(0);
    expect(store.compactDays, 1);
  });

  test('the settings survive a reload', () async {
    final store = await seeded();
    store.setCompactDays(3);
    store.setCompactNames(false);
    // The write is fire-and-forget, like every other pref here.
    await Future<void>.delayed(Duration.zero);

    final reopened = HabitStore();
    await reopened.load();
    expect(reopened.compactDays, 3);
    expect(reopened.compactNames, isFalse);
  });

  testWidgets('one cell per habit per day', (tester) async {
    final store = await seeded();
    store.setCompactDays(4);

    await tester.pumpWidget(app(HomeScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.byType(GridCell), findsNWidgets(8));
    expect(find.text('2 HABITS'), findsOneWidget);
    expect(find.text('Last 4 days'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('hiding names leaves the icons and the cells', (tester) async {
    final store = await seeded();
    store.setCompactNames(false);

    await tester.pumpWidget(app(HomeScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsNothing);
    expect(find.byType(GridCell), findsNWidgets(10));
  });

  testWidgets('a cell records the day it stands for', (tester) async {
    final store = await seeded();
    store.setCompactDays(2);

    await tester.pumpWidget(app(HomeScreen(store: store)));
    await tester.pumpAndSettle();

    // Row one, column one: yesterday for the first habit.
    await tester.tap(find.byType(GridCell).first);
    await tester.pumpAndSettle();

    final read = store.visible.first;
    expect(read.isDoneOn(shiftDays(today(), -1)), isTrue);
    expect(read.doneToday, isFalse);
  });

  testWidgets('the header switch changes the dashboard layout in place',
      (tester) async {
    final store = await seeded();
    store.setCompactLayout(false);

    await tester.pumpWidget(app(RootScreen(store: store)));
    await tester.pumpAndSettle();

    // Cards with grids to begin with.
    expect(find.byType(HabitTile), findsNWidgets(2));
    expect(find.byType(CompactList), findsNothing);

    await tester.tap(find.descendant(
      of: find.byType(LayoutSwitch),
      matching: find.byIcon(Icons.view_list_outlined),
    ));
    await tester.pumpAndSettle();

    // Same page, other layout — nothing was pushed over it.
    expect(find.byType(CompactList), findsOneWidget);
    expect(find.byType(HabitTile), findsNothing);
    expect(find.byType(PageTabs), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(LayoutSwitch),
      matching: find.byIcon(Icons.calendar_view_month_outlined),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(HabitTile), findsNWidgets(2));
  });

  testWidgets('the switch belongs to the dashboard alone', (tester) async {
    final store = await seeded();
    await tester.pumpWidget(app(RootScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.byType(LayoutSwitch), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.byType(LayoutSwitch), findsNothing);
  });

  test('the layout choice survives a reload', () async {
    await seeded(); // seeded() turns the compact layout on
    await Future<void>.delayed(Duration.zero);

    final reopened = HabitStore();
    await reopened.load();
    expect(reopened.compactLayout, isTrue);
  });

  testWidgets('the pill opens the settings, and a chip changes the window', (
    tester,
  ) async {
    final store = await seeded();

    await tester.pumpWidget(app(HomeScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Last 5 days'));
    await tester.pumpAndSettle();
    expect(find.text('Compact list'), findsOneWidget);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(store.compactDays, 3);

    await tester.tap(find.text('Hidden'));
    await tester.pumpAndSettle();
    expect(store.compactNames, isFalse);
  });
}
