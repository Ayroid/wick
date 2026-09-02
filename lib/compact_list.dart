import 'package:flutter/material.dart';

import 'detail.dart';
import 'grid.dart';
import 'home.dart';
import 'store.dart';
import 'theme.dart';

/// The dashboard's other layout: every habit against the last few days, one
/// row each. The card layout answers "how is this habit going"; this answers
/// "what did I actually do this week", and does it without a contribution
/// grid per habit, for anyone who would rather not look at one.
///
/// The cells are the grid's own — same tap to toggle, same hold to open the
/// day — only larger, because here they are the whole control rather than a
/// history strip under one.
///
/// The header's LayoutSwitch chooses between this and the habit cards; the
/// "Last N days" pill is where the shape of this one is set.
class CompactList extends StatelessWidget {
  const CompactList({super.key, required this.store, required this.habits});

  final HabitStore store;
  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    final days = lastDays(store.compactDays);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      children: [
        _RangeBar(store: store, days: days),
        const SizedBox(height: 10),
        _Table(store: store, habits: habits, days: days),
      ],
    );
  }
}


/// The [n] days ending today, oldest first — the order the columns read in.
List<DateTime> lastDays(int n) => [
  for (var i = n - 1; i >= 0; i--) shiftDays(today(), -i),
];

/// "AUG 29 — SEP 2", or a single date when only today is showing.
String rangeLabel(List<DateTime> days) {
  String at(DateTime d) => '${months[d.month - 1]} ${d.day}'.toUpperCase();
  return days.length == 1
      ? at(days.first)
      : '${at(days.first)}  —  ${at(days.last)}';
}

/// What the list covers, and the way into changing it. The pill is the only
/// control on the page, so it carries the tap rather than a second icon.
class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.store, required this.days});

  final HabitStore store;
  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final n = days.length;

    return Row(
      children: [
        SoftCard(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          onTap: () => showCompactSettings(context, store),
          child: Semantics(
            button: true,
            label: 'Showing the last $n days',
            hint: 'Change how many days',
            excludeSemantics: true,
            child: Text(
              n == 1 ? 'Today' : 'Last $n days',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Flexible, not a Spacer: seven days of dates beside the pill is wider
        // than a narrow phone, and the range is the half that can give.
        Expanded(
          child: Text(
            rangeLabel(days),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mono(
              11.5,
              color: gridLabel(context),
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Header row plus one row per habit, hairlines between.
class _Table extends StatelessWidget {
  const _Table({required this.store, required this.habits, required this.days});

  final HabitStore store;
  final List<Habit> habits;
  final List<DateTime> days;

  /// The name column never falls below this, so more days squeeze the cells
  /// rather than clipping every habit to two letters.
  static const _nameFloor = 150.0;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, box) {
          final column = ((box.maxWidth - _nameFloor) / days.length).clamp(
            28.0,
            48.0,
          );
          final cell = (column - 10).clamp(18.0, 38.0);

          return Column(
            children: [
              _Header(count: habits.length, days: days, column: column),
              for (final habit in habits) ...[
                Divider(height: 1, thickness: 1, color: cardEdge(context)),
                HabitAccent(
                  color: habitColorAt(habit.color),
                  child: _HabitRow(
                    store: store,
                    habit: habit,
                    days: days,
                    column: column,
                    cell: cell,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.days,
    required this.column,
  });

  final int count;
  final List<DateTime> days;
  final double column;

  @override
  Widget build(BuildContext context) {
    final muted = gridLabel(context);
    final now = today();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              '$count ${count == 1 ? "HABIT" : "HABITS"}',
              style: mono(11, color: muted, spacing: 1.2),
            ),
          ),
          for (final day in days)
            SizedBox(
              width: column,
              child: Column(
                children: [
                  Text(
                    weekdayShort[day.weekday - 1],
                    style: mono(10.5, color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    // Today is the column being acted on, so it is the one
                    // that reads at full strength.
                    style: mono(
                      12.5,
                      color: day == now
                          ? Theme.of(context).colorScheme.onSurface
                          : muted,
                      weight: day == now ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.store,
    required this.habit,
    required this.days,
    required this.column,
    required this.cell,
  });

  final HabitStore store;
  final Habit habit;
  final List<DateTime> days;
  final double column;
  final double cell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => openHabitDetail(context, store, habit),
              child: Row(
                children: [
                  HabitIcon(habit: habit, size: 34),
                  if (store.compactNames) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          for (final day in days)
            SizedBox(
              width: column,
              child: Center(
                child: GridCell(
                  habit: habit,
                  store: store,
                  day: day,
                  size: cell,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// How wide a window the compact list shows, and whether it names the habits.
/// Floating clear of every edge, the way the day sheet is.
Future<void> showCompactSettings(BuildContext context, HabitStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Material(
        color:
            Theme.of(context).bottomSheetTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => _CompactSettings(store: store),
        ),
      ),
    ),
  );
}

class _CompactSettings extends StatelessWidget {
  const _CompactSettings({required this.store});

  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Compact list', style: text.titleLarge),
          const SizedBox(height: 18),
          Text('How many days to show', style: text.labelSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var n = 1; n <= 7; n++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: n == 7 ? 0 : 6),
                    child: _DayChip(
                      days: n,
                      selected: store.compactDays == n,
                      onTap: () => store.setCompactDays(n),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Habit names', style: text.labelSmall),
          const SizedBox(height: 8),
          Segmented<bool>(
            options: const {false: 'Hidden', true: 'Shown'},
            value: store.compactNames,
            onChanged: store.setCompactNames,
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.days,
    required this.selected,
    required this.onTap,
  });

  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '$days ${days == 1 ? "day" : "days"}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? flameOf(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? null
                : Border.all(color: scheme.surfaceContainerHighest, width: 1.5),
          ),
          child: Text(
            '$days',
            style: mono(
              14,
              color: selected ? Colors.white : scheme.secondary,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
