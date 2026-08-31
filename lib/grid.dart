import 'package:flutter/material.dart';

import 'day_sheet.dart';
import 'store.dart';
import 'theme.dart';

/// The contribution grid: one column per week, oldest on the left, ending with
/// the week containing today. Rows run Monday at the top to Sunday at the
/// bottom.
///
/// How many weeks it shows is decided by how much room it is given rather than
/// fixed, so the same widget fills a full-width card and a narrow tile without
/// clipping or leaving a gutter.
/// The layout every grid on the dashboard, the detail screen and analytics
/// shares: week columns oldest-first ending with today's week, Monday at the
/// top, a month ruler above and a Tue/Thu/Sat gutter beside.
///
/// How many weeks it shows is decided by how much room it is given rather than
/// fixed, so the same frame fills a full-width card and a narrow tile without
/// clipping or leaving a gutter.
///
/// It draws no cells of its own — [cell] does that. Analytics scores a day
/// across every habit, a habit card scores only itself, and neither should own
/// a second copy of this arithmetic.
class GridFrame extends StatelessWidget {
  const GridFrame({
    super.key,
    required this.cell,
    required this.label,
    this.size = 9,
    this.gap = 3,
    this.showMonths = false,
    this.showDays = false,
    this.maxWeeks = 27,
    this.scrollable = false,
  });

  final Widget Function(DateTime day) cell;

  /// What a screen reader hears in place of every individual cell, given the
  /// days actually drawn. A grid read one day at a time is unlistenable.
  final String Function(List<DateTime> days) label;

  final double size;
  final double gap;
  final bool showMonths;
  final bool showDays;

  /// A ceiling on history even when the width would allow more, so a tablet
  /// doesn't render three years of empty cells for a habit added last week.
  final int maxWeeks;

  /// Draw all [maxWeeks] and let the columns scroll sideways, newest in view,
  /// instead of fitting however many happen to be given room. The weekday
  /// gutter stays put; the month ruler scrolls with the columns it names.
  final bool scrollable;

  double get _step => size + gap;
  double get _labelWidth => showDays ? size * 2.6 + 4 : 0;
  double get _monthHeight => showMonths ? size + 6 : 0;

  /// One size for both rulers — a month name and a weekday name are the same
  /// kind of label and reading as two sizes made the grid look accidental.
  double get _labelSize => (_step * 0.72).clamp(8.0, 11.0);

  @override
  Widget build(BuildContext context) {
    // The well is the grid's own ground — dark at night, cream by day, with
    // the cells darkened to match (see `cellLit`).
    //
    // It wraps the LayoutBuilder rather than the other way round, so the
    // measurement is of the room *inside* the padding — measuring outside it
    // fits one column too many and overflows by exactly the inset.
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 9, 4, 10),
      decoration: BoxDecoration(
        color: gridWell(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final room = box.maxWidth - _labelWidth;
          final weeks =
              scrollable ? maxWeeks : (room / _step).floor().clamp(1, maxWeeks);
          final firstMonday = shiftDays(startOfWeek(today()), -7 * (weeks - 1));
          final days = [
            for (var i = 0; i < weeks * 7; i++) shiftDays(firstMonday, i),
          ];

          final columns = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showMonths)
                SizedBox(
                  height: _monthHeight,
                  child: _MonthRuler(
                    firstMonday: firstMonday,
                    weeks: weeks,
                    step: _step,
                    fontSize: _labelSize,
                  ),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var col = 0; col < weeks; col++)
                      Padding(
                        padding:
                            EdgeInsets.only(right: col == weeks - 1 ? 0 : gap),
                        child: Column(
                          children: [
                            for (var row = 0; row < 7; row++)
                              Padding(
                                padding: EdgeInsets.only(
                                    bottom: row == 6 ? 0 : gap),
                                child: cell(days[col * 7 + row]),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );

          return Semantics(
            container: true,
            label: label(days),
            child: SizedBox(
              height: _monthHeight + 7 * _step - gap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDays)
                    _DayGutter(
                      width: _labelWidth,
                      step: _step,
                      cell: size,
                      topInset: _monthHeight,
                      fontSize: _labelSize,
                    ),
                  Expanded(
                    child: scrollable
                        // Reversed rather than driven by a controller: it puts
                        // the newest week at the right edge on first paint,
                        // which is where a controller would have to scroll to
                        // anyway.
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            child: SizedBox(
                              width: weeks * _step - gap,
                              child: columns,
                            ),
                          )
                        : columns,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One habit's history: a lit cell per day it was done.
class ContributionGrid extends StatelessWidget {
  const ContributionGrid({
    super.key,
    required this.habit,
    this.store,
    this.cell = 9,
    this.gap = 3,
    this.showMonths = false,
    this.showDays = false,
    this.maxWeeks = 27,
    this.scrollable = false,
  });

  final Habit habit;

  /// Non-null makes the cells interactive: tap toggles a day, hold opens it.
  /// The dashboard card leaves this off — its cells are far below a usable
  /// touch target, and the card itself is the tap target there.
  final HabitStore? store;

  final double cell;
  final double gap;
  final bool showMonths;
  final bool showDays;
  final int maxWeeks;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return GridFrame(
      size: cell,
      gap: gap,
      showMonths: showMonths,
      showDays: showDays,
      maxWeeks: maxWeeks,
      scrollable: scrollable,
      // Interactive cells carry their own date and state, so the frame stays
      // quiet and lets them speak; display-only ones are summarised instead.
      label: (days) => store != null
          ? ''
          : '${habit.totalDone} days completed in the last ${days.length} days',
      cell: (day) => GridCell(
        habit: habit,
        store: store,
        day: day,
        size: cell,
      ),
    );
  }
}

/// One day. Lit at full flame when done, a faint wash of it when not, and a
/// hollow ring for today while it is still open.
class GridCell extends StatelessWidget {
  const GridCell({
    super.key,
    required this.habit,
    required this.store,
    required this.day,
    required this.size,
  });

  final Habit habit;
  final HabitStore? store;
  final DateTime day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final now = today();
    final future = day.isAfter(now);
    final isToday = day == now;
    final done = habit.isDoneOn(day);
    final amount = habit.amountOn(day);
    // Countable habits earn their way up to full strength rather than jumping
    // there, so a 6-of-8 day is visibly different from a 1-of-8 one.
    final partial = !done && amount > 0;
    // A lit cell is the habit's own colour at full strength, against a faint
    // wash of the same colour for a day it was not.
    final fill = done
        ? accentOf(context)
        : partial
            ? Color.lerp(cellEmpty(context), accentOf(context),
                0.25 + 0.5 * (amount / habit.target))!
            : future
                // Inside the well, so a future day recedes toward it rather
                // than toward the page.
                ? Color.alphaBlend(tint(context, 0.07), gridWell(context))
                : cellEmpty(context);

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: isToday && !done
            ? Border.all(color: accentOf(context), width: 1.4)
            : null,
      ),
    );

    final s = store;
    if (s == null || future) return box;

    final note = habit.noteOn(day);
    return Semantics(
      button: true,
      checked: done,
      label: '${shortDate(day)}, '
          '${habit.isCountable ? "$amount of ${habit.target}" : done ? "done" : "not done"}'
          '${note.isEmpty ? "" : ". Note: $note"}',
      hint: done ? 'Mark as not done' : 'Mark as done',
      onTap: () => s.toggle(habit, day),
      onLongPress: () => showDaySheet(context, s, habit, day),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => s.toggle(habit, day),
        onLongPress: () => showDaySheet(context, s, habit, day),
        child: Tooltip(
          // Manual: Tooltip claims long-press by default and would win it from
          // the day sheet. Hover still shows it on desktop.
          triggerMode: TooltipTriggerMode.manual,
          message: shortDate(day) +
              (habit.isCountable ? ' — $amount/${habit.target}' : '') +
              (note.isEmpty ? '' : '\n$note'),
          child: box,
        ),
      ),
    );
  }
}

/// Tue / Thu / Sat down the left edge. Every other row, as the reference has
/// it — seven stacked labels at this size would be a smear.
class _DayGutter extends StatelessWidget {
  const _DayGutter({
    required this.width,
    required this.step,
    required this.cell,
    required this.topInset,
    required this.fontSize,
  });

  final double width;
  final double step;
  final double cell;
  final double topInset;
  final double fontSize;

  /// The grid's own height is seven cells and six gaps, so the last label row
  /// gets the cell height rather than the full step — otherwise the gutter is
  /// one gap taller than the thing it labels and overflows its parent.
  double _rowHeight(int row) => row == 6 ? cell : step;

  @override
  Widget build(BuildContext context) {
    final muted = gridLabel(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topInset),
          for (var row = 0; row < 7; row++)
            SizedBox(
              height: _rowHeight(row),
              child: row.isOdd
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        weekdays[row].substring(0, 3),
                        style: mono(fontSize, color: muted),
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Month names above the columns they start in. A label is dropped when it
/// would collide with the one before it, so a narrow grid thins out rather
/// than overprinting.
class _MonthRuler extends StatelessWidget {
  const _MonthRuler({
    required this.firstMonday,
    required this.weeks,
    required this.step,
    required this.fontSize,
  });

  final DateTime firstMonday;
  final int weeks;
  final double step;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final muted = gridLabel(context);
    final size = fontSize;
    // Three letters plus tracking, in columns.
    final needed = (size * 2.4 / step).ceil() + 1;

    final labels = <Widget>[];
    var lastCol = -needed;
    var lastMonth = -1;

    for (var col = 0; col < weeks; col++) {
      final month = shiftDays(firstMonday, col * 7).month;
      if (month == lastMonth) continue;
      lastMonth = month;
      if (col - lastCol < needed || col > weeks - needed) continue;
      lastCol = col;
      labels.add(Positioned(
        left: col * step,
        top: 0,
        child: Text(
          months[month - 1].substring(0, 3),
          style: mono(size, color: muted),
        ),
      ));
    }

    return Stack(clipBehavior: Clip.none, children: labels);
  }
}
