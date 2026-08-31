import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/store.dart';

/// The month calendar and the contribution grid both lay themselves out from
/// arithmetic rather than from a layout pass, so the arithmetic is what has to
/// be right. Both walk forward from a Monday.
void main() {
  group('month calendar', () {
    /// The grid the calendar draws: 42 days from the Monday on or before the
    /// 1st. Mirrors `_MonthCalendarState.build`.
    List<DateTime> cells(int year, int month) {
      final first = startOfWeek(DateTime(year, month));
      return [for (var i = 0; i < 42; i++) shiftDays(first, i)];
    }

    test('six rows cover every month of a decade, leap years included', () {
      for (var y = 2020; y <= 2030; y++) {
        for (var m = 1; m <= 12; m++) {
          final grid = cells(y, m);
          final lastDay = DateTime(y, m + 1, 0).day;

          for (var d = 1; d <= lastDay; d++) {
            expect(grid, contains(DateTime(y, m, d)),
                reason: '$y-$m day $d fell outside the six rows');
          }
        }
      }
    });

    test('starts on a Monday and runs unbroken', () {
      final grid = cells(2026, 8);
      expect(grid.first.weekday, DateTime.monday);
      for (var i = 1; i < grid.length; i++) {
        expect(grid[i], shiftDays(grid[i - 1], 1));
      }
    });

    test('the 1st always lands in the first row', () {
      for (var m = 1; m <= 12; m++) {
        expect(cells(2026, m).indexOf(DateTime(2026, m)), lessThan(7));
      }
    });

    test('spill either side belongs to a neighbouring month', () {
      // February 2027 starts on a Monday — the tightest case, where row 0 is
      // entirely in-month and the tail spills furthest.
      final grid = cells(2027, 2);
      expect(grid.first, DateTime(2027, 2, 1));
      expect(grid.where((d) => d.month == 2).length, 28);
      expect(grid.last, DateTime(2027, 3, 14));
    });
  });

  group('contribution grid', () {
    /// Mirrors `ContributionGrid.build`: `weeks` columns of seven, ending with
    /// the week that contains today.
    List<DateTime> cells(DateTime now, int weeks) {
      final first = shiftDays(startOfWeek(now), -7 * (weeks - 1));
      return [for (var i = 0; i < weeks * 7; i++) shiftDays(first, i)];
    }

    test('always contains today, and never ends before it', () {
      for (var i = 0; i < 400; i++) {
        final now = shiftDays(DateTime(2026, 1, 1), i);
        final grid = cells(now, 26);
        expect(grid, contains(now));
        expect(grid.last.isBefore(now), isFalse);
        // Today is in the final column, so at most six days of the future are
        // ever drawn — the rest of its own week.
        expect(grid.last.difference(now).inDays, lessThan(7));
      }
    });

    test('rows are weekdays: every 7th cell shares a weekday', () {
      final grid = cells(DateTime(2026, 8, 31), 26);
      for (var i = 0; i < 7; i++) {
        final column = [
          for (var w = 0; w < 26; w++) grid[w * 7 + i].weekday,
        ];
        expect(column.toSet(), hasLength(1),
            reason: 'row $i mixes weekdays');
        expect(column.first, i + 1); // Monday-first
      }
    });

    test('survives a DST transition without losing or repeating a day', () {
      // 29 March 2026 is a European spring-forward Sunday.
      final grid = cells(DateTime(2026, 4, 5), 4);
      expect(grid.toSet(), hasLength(28));
      expect(grid, contains(DateTime(2026, 3, 29)));
    });
  });
}
