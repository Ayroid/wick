import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/main.dart';
import 'package:habit_tracker/notes_screen.dart';
import 'package:habit_tracker/page_bar.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<HabitStore> seeded() async {
    final store = HabitStore();
    await store.load();
    final read = store.add('Read');
    final run = store.add('Run');
    store.setNote(read, today(), 'Chapter three.');
    store.setNote(run, today(), 'Legs heavy.');
    store.setNote(read, shiftDays(today(), -2), 'Outside for once.');
    return store;
  }

  test('notes group by day, newest first, habits together', () async {
    final store = await seeded();
    final days = notesByDay(store.habits);

    expect(days.map((d) => d.key), [
      dayKey(today()),
      dayKey(shiftDays(today(), -2)),
    ]);
    expect(days.first.notes.map((n) => n.habit.name), ['Read', 'Run']);
    expect(days.last.notes.single.note, 'Outside for once.');
  });

  test('an archived habit keeps its notes — the history still happened',
      () async {
    final store = await seeded();
    store.setArchived(store.habits.first, true);
    expect(notesByDay(store.habits).first.notes.length, 2);
  });

  testWidgets('the empty state explains where notes come from', (tester) async {
    final store = HabitStore();
    await store.load();
    store.add('Read');

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: RootScreen(store: store),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('No notes yet'), findsOneWidget);
    // The count line lives in the shared bar, not the page.
    expect(find.text('Nothing written yet'), findsOneWidget);
  });

  testWidgets('notes sit one swipe past analytics', (tester) async {
    final store = await seeded();

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: RootScreen(store: store),
    ));
    await tester.pumpAndSettle();
    expect(find.text(greeting()), findsOneWidget);

    // Scoped to the top bar: the bottom tabs carry the same words.
    Finder title(String s) =>
        find.descendant(of: find.byType(PageBar), matching: find.text(s));

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(title('Analytics'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(title('Notes'), findsOneWidget);
    expect(find.text('Chapter three.'), findsOneWidget);
  });

  testWidgets('the bottom bar jumps straight to a page', (tester) async {
    final store = await seeded();

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: RootScreen(store: store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
        of: find.byType(PageTabs), matching: find.text('Notes')));
    await tester.pumpAndSettle();
    expect(find.text('Chapter three.'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(PageTabs), matching: find.text('Today')));
    await tester.pumpAndSettle();
    expect(find.text(greeting()), findsOneWidget);
    expect(find.text('Chapter three.'), findsNothing);
  });

  testWidgets('the bar\'s note count stays live', (tester) async {
    // The app above the bar no longer rebuilds on every store change, so the
    // bar has to be listening for itself.
    final store = await seeded();
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: RootScreen(store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(PageTabs), matching: find.text('Notes')));
    await tester.pumpAndSettle();
    expect(find.text('3 notes across 2 days'), findsOneWidget);

    store.setNote(store.habits.last, shiftDays(today(), -5), 'Later addition.');
    await tester.pumpAndSettle();
    expect(find.text('4 notes across 3 days'), findsOneWidget);
  });
}
