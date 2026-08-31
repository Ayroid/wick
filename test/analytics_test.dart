import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/analytics.dart';
import 'package:habit_tracker/store.dart';

/// An id encoding a creation date, the way HabitStore.add builds them.
String idCreated(int daysAgo) =>
    shiftDays(today(), -daysAgo).microsecondsSinceEpoch.toString();

Habit habit({
  required int startedDaysAgo,
  List<int> doneDaysAgo = const [],
  int perWeek = 7,
  String name = 'h',
}) =>
    Habit(
      id: idCreated(startedDaysAgo),
      name: name,
      perWeek: perWeek,
      createdAt: dayKey(shiftDays(today(), -startedDaysAgo)),
      log: {for (final d in doneDaysAgo) dayKey(shiftDays(today(), -d)): 1},
    );

void main() {
  test('startedOn uses the recorded creation day', () {
    expect(habit(startedDaysAgo: 10).startedOn, shiftDays(today(), -10));
  });

  test('a new habit is created today by default', () {
    expect(Habit(id: 'x', name: 'h').createdAt, dayKey(today()));
    expect(Habit(id: 'x', name: 'h').startedOn, today());
  });

  test('imported history older than the record wins', () {
    final imported = Habit(
      id: 'x',
      name: 'h',
      createdAt: dayKey(shiftDays(today(), -2)),
      log: {dayKey(shiftDays(today(), -30)): 1},
    );
    expect(imported.startedOn, shiftDays(today(), -30));
  });

  test('a habit is not scored for days before it existed', () {
    // Created 2 days ago, done both of those days plus today: a perfect record.
    final a = Analytics([habit(startedDaysAgo: 2, doneDaysAgo: [0, 1, 2])]);
    expect(a.completionRate, 1.0);
  });

  test('completion rate counts misses inside the window', () {
    // Active 10 days, done 5 of them.
    final a = Analytics([
      habit(startedDaysAgo: 9, doneDaysAgo: [0, 1, 2, 3, 4]),
    ], window: 10);
    expect(a.completionRate, closeTo(0.5, 0.001));
  });

  test('weekly habits are expected only perWeek/7 of the time', () {
    // 3x/week, active 7 days, done exactly 3 — that is a full score.
    final a = Analytics([
      habit(startedDaysAgo: 6, doneDaysAgo: [0, 2, 4], perWeek: 3),
    ], window: 7);
    expect(a.completionRate, closeTo(1.0, 0.001));
  });

  test('the rate is capped, so overshooting a weekly quota cannot exceed 100%',
      () {
    final a = Analytics([
      habit(startedDaysAgo: 6, doneDaysAgo: [0, 1, 2, 3, 4, 5, 6], perWeek: 2),
    ], window: 7);
    expect(a.completionRate, 1.0);
  });

  test('dayScore is the share of that day\'s habits completed', () {
    final a = Analytics([
      habit(startedDaysAgo: 5, doneDaysAgo: [0], name: 'a'),
      habit(startedDaysAgo: 5, doneDaysAgo: [0], name: 'b'),
      habit(startedDaysAgo: 5, doneDaysAgo: [], name: 'c'),
      habit(startedDaysAgo: 5, doneDaysAgo: [], name: 'd'),
    ]);
    expect(a.dayScore(today()), 0.5);
  });

  test('a day before any habit existed is flagged, not scored zero', () {
    final a = Analytics([habit(startedDaysAgo: 3)]);
    expect(a.hasAnyHabitOn(shiftDays(today(), -2)), isTrue);
    expect(a.hasAnyHabitOn(shiftDays(today(), -9)), isFalse);
  });

  test('totalCheckOffs sums every habit\'s history', () {
    final a = Analytics([
      habit(startedDaysAgo: 20, doneDaysAgo: [0, 1, 2]),
      habit(startedDaysAgo: 20, doneDaysAgo: [0, 5]),
    ]);
    expect(a.totalCheckOffs, 5);
  });

  test('longestActiveStreak names the habit holding it', () {
    final short = habit(startedDaysAgo: 20, doneDaysAgo: [0], name: 'short');
    final long = habit(startedDaysAgo: 20, doneDaysAgo: [0, 1, 2, 3], name: 'long');
    final best = Analytics([short, long]).longestActiveStreak;
    expect(best?.$1.name, 'long');
    expect(best?.$2, 4);
  });

  test('longestActiveStreak is null with no habits', () {
    expect(Analytics([]).longestActiveStreak, isNull);
  });

  test('byWeekday only reports days the habit was alive for', () {
    final a = Analytics([habit(startedDaysAgo: 2)], window: 30);
    // Three days alive, so at most three distinct weekdays measured.
    expect(a.byWeekday.length, 3);
  });

  test('bestAndWorstWeekday stays quiet until the spread is meaningful', () {
    // Perfect every day: no weekday stands out.
    final even = Analytics([
      habit(startedDaysAgo: 20, doneDaysAgo: List.generate(21, (i) => i)),
    ], window: 21);
    expect(even.bestAndWorstWeekday, isNull);

    // Never done on the weekday three weeks of Mondays fall on.
    final mondays = [
      for (var i = 0; i <= 20; i++)
        if (shiftDays(today(), -i).weekday != DateTime.monday) i,
    ];
    final skewed = Analytics([
      habit(startedDaysAgo: 20, doneDaysAgo: mondays),
    ], window: 21);
    expect(skewed.bestAndWorstWeekday?.$2, DateTime.monday);
  });

  test('perHabit ranks the strongest first', () {
    final a = Analytics([
      habit(startedDaysAgo: 9, doneDaysAgo: [0], name: 'weak'),
      habit(startedDaysAgo: 9, doneDaysAgo: List.generate(10, (i) => i), name: 'strong'),
    ], window: 10);
    expect(a.perHabit.map((r) => r.$1.name), ['strong', 'weak']);
    expect(a.perHabit.first.$2, 1.0);
    expect(a.perHabit.last.$2, closeTo(0.1, 0.001));
  });

  test('no habits means zeroes, not a crash', () {
    final a = Analytics([]);
    expect(a.isEmpty, isTrue);
    expect(a.completionRate, 0);
    expect(a.totalCheckOffs, 0);
    expect(a.byWeekday, isEmpty);
    expect(a.dayScore(today()), 0);
  });

  group('weeklyTrend', () {
    test('is oldest first and ends with the current week', () {
      final a = Analytics([habit(startedDaysAgo: 60, doneDaysAgo: [0])]);
      final t = a.weeklyTrend(weeks: 4);
      expect(t, hasLength(4));
      expect(t.last.$1, startOfWeek(today()));
      for (var i = 1; i < t.length; i++) {
        expect(t[i].$1, shiftDays(t[i - 1].$1, 7));
      }
    });

    test('drops weeks before the habit existed rather than plotting zero', () {
      final h = habit(startedDaysAgo: 10);
      final t = Analytics([h]).weeklyTrend(weeks: 12);

      // Twelve weeks were asked for; only the ones the habit lived through
      // come back — a week it straddles counts, a week entirely before it
      // does not. Ten days touches at most three calendar weeks.
      expect(t, isNotEmpty);
      expect(t.length, lessThanOrEqualTo(3));
      for (final (monday, _) in t) {
        expect(shiftDays(monday, 6).isBefore(h.startedOn), isFalse,
            reason: 'week of $monday ended before the habit existed');
      }
    });

    test('the running week is scored on days lived, not days remaining', () {
      // Done every day of this week so far. The days still to come must not
      // drag the point down, or the last week always looks like a collapse.
      final monday = startOfWeek(today());
      final lived = today().difference(monday).inDays + 1;
      final a = Analytics([
        habit(
          startedDaysAgo: 40,
          doneDaysAgo: [for (var i = 0; i < lived; i++) i],
        )
      ]);
      expect(a.weeklyTrend(weeks: 2).last.$2, 1.0);
    });

    test('a half-kept week scores near half', () {
      final monday = startOfWeek(shiftDays(today(), -7));
      final done = [
        for (var i = 0; i < 3; i++)
          today().difference(shiftDays(monday, i)).inDays,
      ];
      final a = Analytics([habit(startedDaysAgo: 40, doneDaysAgo: done)]);
      final lastWeek = a.weeklyTrend(weeks: 2).first;
      expect(lastWeek.$1, monday);
      expect(lastWeek.$2, closeTo(3 / 7, 0.001));
    });

    test('no habits is an empty trend, not a row of zeroes', () {
      expect(Analytics([]).weeklyTrend(), isEmpty);
    });
  });

  group('clean days', () {
    test('counts only days where every due habit was done', () {
      final a = Analytics([
        habit(startedDaysAgo: 5, doneDaysAgo: [0, 1, 2], name: 'a'),
        habit(startedDaysAgo: 5, doneDaysAgo: [0, 2], name: 'b'),
      ]);
      // Day 0 and day 2 have both; day 1 has only one of the two.
      expect(a.perfectDays, 2);
    });

    test('days before any habit existed are not measured', () {
      final a = Analytics([habit(startedDaysAgo: 3, doneDaysAgo: [0])]);
      expect(a.measuredDays, 4); // today plus three
      expect(a.perfectDays, 1);
    });

    test('no habits measures nothing', () {
      expect(Analytics([]).measuredDays, 0);
      expect(Analytics([]).perfectDays, 0);
    });
  });
}
