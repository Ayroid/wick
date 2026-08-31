import 'store.dart';

/// Aggregates across every active habit. Pure math over the store's data — no
/// widgets, so it can be tested directly.
class Analytics {
  Analytics(this.habits, {this.window = defaultWindow});

  /// The window every screen uses. A constant so callers that only need the
  /// number — the top bar's subtitle — don't have to build an Analytics.
  static const defaultWindow = 30;

  final List<Habit> habits;

  /// How many days back the rate-based figures look.
  final int window;

  bool get isEmpty => habits.isEmpty;

  /// Habits that existed on [day] — a habit can't miss a day before it existed.
  Iterable<Habit> _activeOn(DateTime day) =>
      habits.where((h) => !h.startedOn.isAfter(day));

  /// Fraction of that day's habits that were done, 0..1. Days before any habit
  /// existed score 0 and are excluded by callers rather than folded in.
  double dayScore(DateTime day) {
    final active = _activeOn(day).toList();
    if (active.isEmpty) return 0;
    return active.where((h) => h.isDoneOn(day)).length / active.length;
  }

  bool hasAnyHabitOn(DateTime day) => _activeOn(day).isNotEmpty;

  /// Built once. Every rate getter walks it per habit, so recomputing it made
  /// the window's worth of DateTimes once for each habit on the list.
  late final List<DateTime> _windowDays = [
    for (var i = window - 1; i >= 0; i--) shiftDays(today(), -i)
  ];

  /// Done divided by expected. A `3× per week` habit is expected on 3/7 of its
  /// active days, so weekly habits aren't scored as if they were daily.
  double get completionRate {
    var done = 0.0, expected = 0.0;
    for (final h in habits) {
      for (final day in _windowDays) {
        if (h.startedOn.isAfter(day)) continue;
        expected += h.perWeek / 7;
        if (h.isDoneOn(day)) done++;
      }
    }
    if (expected == 0) return 0;
    return (done / expected).clamp(0.0, 1.0);
  }

  int get totalCheckOffs =>
      habits.fold(0, (sum, h) => sum + h.totalDone);

  /// The strongest run going right now, with the habit that owns it.
  (Habit, int)? get longestActiveStreak {
    Habit? best;
    var bestN = 0;
    for (final h in habits) {
      final n = h.streak;
      if (n > bestN) {
        best = h;
        bestN = n;
      }
    }
    return best == null ? null : (best, bestN);
  }

  /// Completion rate per weekday (1 = Monday … 7 = Sunday) over the window.
  /// Weekdays with nothing scheduled yet are absent rather than zero.
  Map<int, double> get byWeekday {
    final done = <int, int>{};
    final possible = <int, int>{};
    for (final h in habits) {
      for (final day in _windowDays) {
        if (h.startedOn.isAfter(day)) continue;
        possible[day.weekday] = (possible[day.weekday] ?? 0) + 1;
        if (h.isDoneOn(day)) done[day.weekday] = (done[day.weekday] ?? 0) + 1;
      }
    }
    return {
      for (final e in possible.entries)
        if (e.value > 0) e.key: (done[e.key] ?? 0) / e.value,
    };
  }

  /// The weekday you show up most, and least — null until there's enough
  /// spread to be worth saying.
  (int, int)? get bestAndWorstWeekday {
    final rates = byWeekday;
    if (rates.length < 7) return null;
    final sorted = rates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.first.value - sorted.last.value < 0.15) return null;
    return (sorted.first.key, sorted.last.key);
  }

  /// Completion rate for each of the last [weeks] weeks, oldest first, paired
  /// with that week's Monday. Weeks before any habit existed are absent rather
  /// than plotted as zero — a flat run of nothing at the left of a chart reads
  /// as failure, not as "you weren't here yet".
  List<(DateTime, double)> weeklyTrend({int weeks = 12}) {
    final out = <(DateTime, double)>[];
    final thisMonday = startOfWeek(today());

    for (var w = weeks - 1; w >= 0; w--) {
      final monday = shiftDays(thisMonday, -7 * w);
      var done = 0.0, expected = 0.0;
      for (final h in habits) {
        for (var i = 0; i < 7; i++) {
          final day = shiftDays(monday, i);
          // The current week is still running; scoring its unlived days as
          // misses would drop the last point every Monday morning.
          if (day.isAfter(today()) || h.startedOn.isAfter(day)) continue;
          expected += h.perWeek / 7;
          if (h.isDoneOn(day)) done++;
        }
      }
      if (expected > 0) out.add((monday, (done / expected).clamp(0.0, 1.0)));
    }
    return out;
  }

  /// Days in the window where every habit due was done. The one figure that
  /// says "a clean day" rather than an average.
  int get perfectDays => _windowDays
      .where((d) => hasAnyHabitOn(d) && dayScore(d) == 1)
      .length;

  /// Days the window actually measured — habits have to have existed.
  int get measuredDays => _windowDays.where(hasAnyHabitOn).length;

  /// Per-habit completion over the window, strongest first.
  List<(Habit, double)> get perHabit {
    final rows = habits.map((h) {
      var done = 0.0, expected = 0.0;
      for (final day in _windowDays) {
        if (h.startedOn.isAfter(day)) continue;
        expected += h.perWeek / 7;
        if (h.isDoneOn(day)) done++;
      }
      return (h, expected == 0 ? 0.0 : (done / expected).clamp(0.0, 1.0));
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return rows;
  }
}
