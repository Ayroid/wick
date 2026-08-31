import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/detail.dart';
import 'package:habit_tracker/edit_sheet.dart';
import 'package:habit_tracker/home.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every accent scope in the tree, outermost first.
List<Color> accents(WidgetTester tester) => tester
    .widgetList<HabitAccent>(find.byType(HabitAccent))
    .map((a) => a.color)
    .toList();

Widget wrap(Widget child, {bool dark = false}) =>
    MaterialApp(theme: appTheme(dark: dark), home: child);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('on cream the grid well is translucent, so card hover reaches it',
      (tester) async {
    late Color light, dark;
    await tester.pumpWidget(wrap(Builder(
        key: const Key('light'),
        builder: (c) => Text('${light = gridWell(c)}'))));
    await tester.pumpWidget(
        wrap(
            Builder(
                key: const Key('dark'),
                builder: (c) => Text('${dark = gridWell(c)}')),
            dark: true),
        );
    // MaterialApp lerps between themes, so the dark values land a frame later.
    await tester.pumpAndSettle();
    // Opaque would paint over the InkWell's hover and press ink, which the
    // card draws on the Material beneath its children — and would put a second
    // background colour inside a card that has one.
    expect(light.a, 0.0);
    // At night the well is a darker ground than the card, not a wash of it.
    expect(dark.a, 1.0);
  });

  group('the model carries a swatch', () {
    test('a new habit takes the default', () {
      expect(Habit(id: 'x', name: 'h').color, defaultHabitColor);
    });

    test('it survives a save and reload', () {
      final h = Habit(id: 'x', name: 'h', color: 13);
      expect(Habit.fromJson(jsonDecode(jsonEncode(h.toJson()))).color, 13);
    });

    test('data written before colours existed reads as the default', () {
      // Exactly what an export from the previous version looks like.
      final legacy = Habit.fromJson({
        'id': '1',
        'name': 'Read',
        'done': ['2026-08-30'],
      });
      expect(legacy.color, defaultHabitColor);
      expect(legacy.isDoneOn(DateTime(2026, 8, 30)), isTrue);
    });

    test('editing a habit can change only its colour', () async {
      final store = HabitStore();
      await store.load();
      final h = store.add('Read', emoji: '📖', target: 4);
      store.edit(h, color: 7);

      expect(h.color, 7);
      expect(h.name, 'Read');
      expect(h.emoji, '📖');
      expect(h.target, 4);
    });
  });

  group('the accent reaches the screen', () {
    testWidgets('each card scopes to its own habit', (tester) async {
      final store = HabitStore();
      await store.load();
      store.add('Blue one', color: 10);
      store.add('Rose one', color: 16);

      await tester.pumpWidget(wrap(HomeScreen(store: store), dark: true));
      await tester.pumpAndSettle();

      expect(accents(tester), [habitColorAt(10), habitColorAt(16)]);
    });

    testWidgets('a habit is the same colour in both themes', (tester) async {
      final store = HabitStore();
      await store.load();
      store.add('Lime', color: 4);

      await tester.pumpWidget(wrap(HomeScreen(store: store), dark: true));
      await tester.pumpAndSettle();
      final night = accents(tester).single;

      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pumpAndSettle();
      final day = accents(tester).single;

      // One value per swatch. Darkening it for light mode was tried and
      // looked like mud; the grid gets a dark well instead, so the colour
      // itself never has to change.
      expect(day, night);
      expect(day, habitColors[4].value);
    });

    testWidgets('the detail screen wears the habit colour', (tester) async {
      final store = HabitStore();
      await store.load();
      final h = store.add('Violet', color: 12);

      await tester.pumpWidget(
          wrap(HabitDetailScreen(store: store, habit: h), dark: true));
      await tester.pumpAndSettle();

      expect(accents(tester), contains(habitColorAt(12)));
    });

    testWidgets('an out-of-range stored index renders rather than crashing',
        (tester) async {
      final store = HabitStore();
      await store.load();
      store.add('Corrupt').color = 999;

      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(accents(tester).single, habitColors.last.value);
    });
  });

  group('picking a colour', () {
    testWidgets('the sheet previews the pick before it is saved',
        (tester) async {
      final store = HabitStore();
      await store.load();

      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEditSheet(context, store),
              child: const Text('open'),
            ),
          ),
        ),
        dark: true,
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The sheet starts on the default and follows the swatch you tap, so
      // the icon hero and fields show the colour before Save is pressed.
      expect(accents(tester).single, habitColorAt(defaultHabitColor));

      // The picker sits below the fold in a phone-sized sheet.
      await tester.ensureVisible(find.bySemanticsLabel('Teal'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Teal'));
      await tester.pumpAndSettle();
      expect(accents(tester).single, habitColors[7].value);

      await tester.enterText(find.byType(TextField).first, 'Swim');
      await tester.pumpAndSettle();
      // Still Teal after the field rebuild — the pick is not lost to a keypress.
      expect(accents(tester).single, habitColors[7].value);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(store.habits.single.color, 7);
    });

    testWidgets('every swatch is reachable and named', (tester) async {
      final store = HabitStore();
      await store.load();

      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEditSheet(context, store),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final swatch in habitColors) {
        expect(find.bySemanticsLabel(swatch.name), findsOneWidget,
            reason: '${swatch.name} is not offered or not labelled');
      }
    });
  });
}
