import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/store.dart';

/// N days before today, so the cases don't rot with the calendar.
String daysAgo(int n) => dayKey(shiftDays(today(), -n));

Habit daily(List<int> agos, {int target = 1}) => Habit(
      id: 'x',
      name: 'h',
      target: target,
      log: {for (final a in agos) daysAgo(a): target},
    );

void main() {
  group('daily streak', () {
    test('no history', () => expect(daily([]).streak, 0));
    test('today only', () => expect(daily([0]).streak, 1));
    test('yesterday only, today still open',
        () => expect(daily([1]).streak, 1));
    test('three-day run ending today', () => expect(daily([0, 1, 2]).streak, 3));
    test('a gap breaks the run, only the recent side counts',
        () => expect(daily([0, 1, 3, 4, 5]).streak, 2));
    test('last done two days ago is a broken streak',
        () => expect(daily([2, 3]).streak, 0));
  });

  group('best streak', () {
    test('empty', () => expect(daily([]).bestStreak, 0));
    test('finds the longest past run, not the current one',
        () => expect(daily([0, 5, 6, 7, 8]).bestStreak, 4));
    test('equals the current streak when that is the longest',
        () => expect(daily([0, 1, 2]).bestStreak, 3));
  });

  group('countable habits', () {
    test('below target does not count as done', () {
      final h = Habit(id: 'x', name: 'water', target: 8, log: {daysAgo(0): 6});
      expect(h.isDoneOn(today()), isFalse);
      expect(h.streak, 0);
      expect(h.totalDone, 0);
    });

    test('at or above target counts', () {
      final h = Habit(id: 'x', name: 'water', target: 8,
          log: {daysAgo(0): 8, daysAgo(1): 9});
      expect(h.streak, 2);
      expect(h.totalDone, 2);
    });
  });

  group('weekly habits count weeks, not days', () {
    // Anchor on this week's Monday so the cases don't straddle a week boundary.
    int agoFor(int weeksBack, int dayOfWeek) => today()
        .difference(shiftDays(startOfWeek(today()), -7 * weeksBack + dayOfWeek))
        .inDays;

    Habit weekly(List<int> agos, {int perWeek = 3}) => Habit(
          id: 'x', name: 'gym', perWeek: perWeek,
          log: {for (final a in agos) daysAgo(a): 1},
        );

    test('an unfinished current week does not break the streak', () {
      // Last week hit 3; this week has nothing yet.
      final h = weekly([agoFor(1, 0), agoFor(1, 1), agoFor(1, 2)]);
      expect(h.streak, 1);
    });

    test('two full weeks in a row', () {
      final h = weekly([
        for (var w = 0; w < 2; w++) ...[agoFor(w, 0), agoFor(w, 1), agoFor(w, 2)]
      ]);
      expect(h.streak, 2);
    });

    test('a week under quota ends the streak', () {
      final h = weekly([agoFor(1, 0), agoFor(2, 0), agoFor(2, 1), agoFor(2, 2)]);
      expect(h.streak, 0); // last week only managed 1 of 3
    });

    test('doneDaysInWeek counts only that week', () {
      final h = weekly([agoFor(0, 0), agoFor(0, 1), agoFor(1, 0)]);
      expect(h.doneDaysInWeek(today()), 2);
    });
  });

  group('day arithmetic', () {
    test('shiftDays crosses month boundaries', () {
      expect(dayKey(shiftDays(DateTime(2026, 3, 1), -1)), '2026-02-28');
      expect(dayKey(shiftDays(DateTime(2024, 3, 1), -1)), '2024-02-29');
    });

    test('startOfWeek is Monday', () {
      expect(startOfWeek(DateTime(2026, 8, 30)).weekday, DateTime.monday);
      expect(dayKey(startOfWeek(DateTime(2026, 8, 30))), '2026-08-24');
    });

    test('day keys sort chronologically as strings', () {
      final keys = [DateTime(2026, 12, 1), DateTime(2026, 2, 3), DateTime(2026, 2, 20)]
          .map(dayKey)
          .toList()
        ..sort();
      expect(keys, ['2026-02-03', '2026-02-20', '2026-12-01']);
    });
  });
}
