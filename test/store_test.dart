import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/icons.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/templates.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<HabitStore> loaded() async {
  final s = HabitStore();
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('habits and their history survive a restart', () async {
    final first = await loaded();
    first.add('Read');
    first.add('Gym');
    first.bump(first.habits.first, today());
    await Future<void>.delayed(Duration.zero); // let the async save land

    final second = await loaded();
    expect(second.habits.map((h) => h.name), ['Read', 'Gym']);
    expect(second.habits.first.doneToday, isTrue);
    expect(second.habits.first.streak, 1);
    expect(second.habits.last.doneToday, isFalse);
  });

  test('v1 data (a bare list of done days) still loads', () async {
    SharedPreferences.setMockInitialValues({
      'habits': jsonEncode([
        {'id': '1', 'name': 'Read', 'done': [dayKey(today())]}
      ]),
    });
    final store = await loaded();
    expect(store.habits.single.name, 'Read');
    expect(store.habits.single.doneToday, isTrue);
    expect(store.habits.single.target, 1);
    expect(store.habits.single.perWeek, 7);
  });

  test('corrupt stored data starts empty instead of throwing', () async {
    SharedPreferences.setMockInitialValues({'habits': 'not json'});
    final store = await loaded();
    expect(store.habits, isEmpty);
    expect(store.loaded, isTrue);
  });

  test('bump wraps past the target, so one control both counts and clears',
      () async {
    final store = await loaded();
    final h = store.add('Water', target: 3);
    for (final expected in [1, 2, 3, 0]) {
      store.bump(h, today());
      expect(h.amountOn(today()), expected);
    }
  });

  test('toggle sets a day straight to done or clear', () async {
    final store = await loaded();
    final h = store.add('Water', target: 3);
    store.toggle(h, today());
    expect(h.amountOn(today()), 3);
    store.toggle(h, today());
    expect(h.log, isEmpty);
  });

  test('delete returns the index so undo restores the position', () async {
    final store = await loaded();
    store.add('A');
    final b = store.habits[0];
    store.add('C');
    final i = store.remove(b);
    expect(store.habits.map((h) => h.name), ['C']);
    store.insertAt(i, b);
    expect(store.habits.map((h) => h.name), ['A', 'C']);
  });

  test('archived habits leave the list but keep their data', () async {
    final store = await loaded();
    final h = store.add('Gym');
    store.bump(h, today());
    store.setArchived(h, true);
    expect(store.visible, isEmpty);
    expect(store.archived.single, h);
    expect(store.activeCount, 0);
    store.setArchived(h, false);
    expect(store.visible.single.streak, 1);
  });

  test('visible keeps the manual order, done or not', () async {
    final store = await loaded();
    for (final n in ['A', 'B', 'C', 'D']) {
      store.add(n);
    }
    store.bump(store.habits[0], today()); // A done
    store.bump(store.habits[2], today()); // C done
    expect(store.visible.map((h) => h.name), ['A', 'B', 'C', 'D']);
  });

  test('reorder moves a habit relative to what the user sees', () async {
    final store = await loaded();
    for (final n in ['A', 'B', 'C']) {
      store.add(n);
    }
    // Drag A (index 0) down to the end.
    store.reorder(store.visible, 0, 2);
    expect(store.habits.map((h) => h.name), ['B', 'C', 'A']);
    // And back to the front.
    store.reorder(store.visible, 2, 0);
    expect(store.habits.map((h) => h.name), ['A', 'B', 'C']);
  });

  test('export round-trips through import', () async {
    final store = await loaded();
    final h = store.add('Water',
        description: 'Eight glasses', emoji: '💧', target: 8, perWeek: 5);
    store.bump(h, today());
    final backup = store.exportJson();

    final other = await loaded();
    other.importJson(backup);
    final restored = other.habits.single;
    expect(restored.name, 'Water');
    expect(restored.emoji, '💧');
    expect(restored.description, 'Eight glasses');
    expect(restored.target, 8);
    expect(restored.perWeek, 5);
    expect(restored.amountOn(today()), 1);
  });

  test('a bad import throws before it destroys the existing data', () async {
    final store = await loaded();
    store.add('Keep me');
    expect(() => store.importJson('{}'), throwsA(anything));
    expect(store.habits.single.name, 'Keep me');
  });

  test('theme choice persists', () async {
    final first = await loaded();
    expect(first.themeMode, ThemeMode.light);
    first.setThemeMode(ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);
    expect((await loaded()).themeMode, ThemeMode.dark);
  });

  test('onboarding is shown once and remembered', () async {
    final first = await loaded();
    expect(first.onboarded, isFalse);
    first.completeOnboarding();
    await Future<void>.delayed(Duration.zero);
    expect((await loaded()).onboarded, isTrue);
  });

  test('starter templates carry their own icon and frequency', () async {
    final store = await loaded();
    final walk = starterGroups['Health']!.firstWhere((t) => t.name == 'Go for a walk');
    final water = starterGroups['Food']!.firstWhere((t) => t.name == 'Drink water');
    final gym = starterGroups['Health']!.firstWhere((t) => t.name == 'Exercise');

    for (final t in [walk, water, gym]) {
      store.add(t.name, icon: t.icon, target: t.target, perWeek: t.perWeek);
    }

    expect(store.habits.map((h) => h.name),
        ['Go for a walk', 'Drink water', 'Exercise']);
    expect(store.habits[1].target, 8); // countable
    expect(store.habits[1].isCountable, isTrue);
    expect(store.habits[2].perWeek, 3); // weekly, so streaks count weeks
    expect(store.habits[2].isWeekly, isTrue);
    expect(store.habits.every((h) => h.icon.isNotEmpty), isTrue);
  });

  test('every template describes itself correctly', () {
    final all = starterGroups.values.expand((g) => g).toList();
    expect(all, isNotEmpty);
    for (final t in all) {
      expect(t.name.trim(), isNotEmpty);
      expect(t.icon.trim(), isNotEmpty);
      // A template naming an icon that does not exist would silently fall
      // back to the default, and every suggestion would look the same.
      expect(iconByKey, contains(t.icon));
      expect(t.perWeek, inInclusiveRange(1, 7));
      expect(t.target, greaterThanOrEqualTo(1));
      if (t.target > 1) {
        expect(t.schedule, '${t.target} a day');
      } else if (t.perWeek == 7) {
        expect(t.schedule, 'Every day');
      } else {
        expect(t.schedule, '${t.perWeek}× a week');
      }
    }
    // Names are what the person sees in their list — no accidental twins.
    expect(all.map((t) => t.name).toSet().length, all.length);
  });

  group('createdAt migration', () {
    test('records the creation day and persists it', () async {
      final store = await loaded();
      store.add('Read');
      await Future<void>.delayed(Duration.zero);
      expect((await loaded()).habits.single.createdAt, dayKey(today()));
    });

    test('old records recover it from the timestamp id', () async {
      final made = shiftDays(today(), -12);
      SharedPreferences.setMockInitialValues({
        'habits': jsonEncode([
          {
            'id': made.microsecondsSinceEpoch.toString(),
            'name': 'Read',
            'log': {dayKey(shiftDays(today(), -3)): 1},
          }
        ]),
      });
      expect((await loaded()).habits.single.createdAt, dayKey(made));
    });

    test('an unparseable id falls back to the earliest logged day', () async {
      SharedPreferences.setMockInitialValues({
        'habits': jsonEncode([
          {
            'id': 'hand-edited',
            'name': 'Read',
            'log': {dayKey(shiftDays(today(), -5)): 1},
          }
        ]),
      });
      expect((await loaded()).habits.single.createdAt,
          dayKey(shiftDays(today(), -5)));
    });

    test('an unparseable id with no history falls back to today', () async {
      SharedPreferences.setMockInitialValues({
        'habits': jsonEncode([
          {'id': 'hand-edited', 'name': 'Read'}
        ]),
      });
      expect((await loaded()).habits.single.createdAt, dayKey(today()));
    });
  });

  group('day notes', () {
    test('a note is written, edited, and survives a restart', () async {
      final store = await loaded();
      final h = store.add('Read');
      store.setNote(h, today(), '  Finished chapter 3  ');
      await Future<void>.delayed(Duration.zero);

      final back = (await loaded()).habits.single;
      expect(back.noteOn(today()), 'Finished chapter 3'); // trimmed
      expect(back.notedDays, [dayKey(today())]);
    });

    test('an empty note clears the day instead of storing a blank', () async {
      final store = await loaded();
      final h = store.add('Read');
      store.setNote(h, today(), 'something');
      store.setNote(h, today(), '   ');
      expect(h.notes, isEmpty);
      expect(h.noteOn(today()), '');
    });

    test('notedDays is newest first', () async {
      final store = await loaded();
      final h = store.add('Read');
      for (final by in [-5, -1, -9]) {
        store.setNote(h, shiftDays(today(), by), 'day $by');
      }
      expect(h.notedDays,
          [-1, -5, -9].map((by) => dayKey(shiftDays(today(), by))).toList());
    });

    test('records with no notes key still load', () async {
      SharedPreferences.setMockInitialValues({
        'habits': jsonEncode([
          {'id': '1', 'name': 'Read', 'log': {dayKey(today()): 1}}
        ]),
      });
      expect((await loaded()).habits.single.notes, isEmpty);
    });
  });

  test('startedOn follows the log when the earliest day is removed', () async {
    // startedOn is cached against log.length; clearing the oldest day has to
    // move it, or analytics keeps scoring days the habit no longer covers.
    final store = await loaded();
    final h = store.add('Read');
    final old = shiftDays(today(), -20);
    store.toggle(h, old);
    expect(h.startedOn, old);

    store.toggle(h, old); // back off again
    expect(h.startedOn, parseDay(h.createdAt));
  });
}
