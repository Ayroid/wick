import 'dart:async';

import 'package:flutter/material.dart';

import 'day_sheet.dart';
import 'edit_sheet.dart';
import 'grid.dart';
import 'home.dart';
import 'share_card.dart';
import 'store.dart';
import 'theme.dart';

void openHabitDetail(BuildContext context, HabitStore store, Habit habit) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => HabitDetailScreen(store: store, habit: habit),
  ));
}

class HabitDetailScreen extends StatelessWidget {
  const HabitDetailScreen({
    super.key,
    required this.store,
    required this.habit,
  });

  final HabitStore store;
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // Gone from under us (undo removed it, or an import replaced
        // everything) — bail out rather than render a ghost.
        if (!store.habits.contains(habit)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final text = Theme.of(context).textTheme;

        return HabitAccent(
          color: habitColorAt(habit.color),
          child: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // Round buttons floating on the page rather than an app bar:
                // the reference gives its detail screen no chrome bar at all,
                // and the habit's own name is the title.
                Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.chevron_left_rounded,
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                    const Spacer(),
                    RoundIconButton(
                      icon: Icons.ios_share_rounded,
                      onPressed: () => showShareCard(context, habit),
                      tooltip: 'Share progress',
                    ),
                    const SizedBox(width: 8),
                    RoundIconButton(
                      icon: Icons.edit_outlined,
                      onPressed: () => showEditSheet(context, store, habit),
                      tooltip: 'Edit',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    HabitIcon(habit: habit, size: 54),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(habit.name,
                              style: text.headlineLarge?.copyWith(fontSize: 25)),
                          const SizedBox(height: 2),
                          Text(
                            habit.description.isEmpty
                                ? _schedule(habit)
                                : habit.description,
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TintCard(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: ContributionGrid(
                    habit: habit,
                    store: store,
                    cell: 11,
                    gap: 3.5,
                    showMonths: true,
                    showDays: true,
                    // A year back, scrolled to this week.
                    maxWeeks: 53,
                    scrollable: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TintChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '${habit.streak}',
                      dim: habit.streak == 0,
                      semanticsLabel: 'Current streak: ${habit.streak} '
                          '${habit.isWeekly ? "weeks" : "days"}',
                    ),
                    const SizedBox(width: 8),
                    TintChip(
                      icon: Icons.emoji_events_rounded,
                      label: '${habit.bestStreak}',
                      dim: habit.bestStreak == 0,
                      semanticsLabel: 'Best streak: ${habit.bestStreak} '
                          '${habit.isWeekly ? "weeks" : "days"}',
                    ),
                    const SizedBox(width: 8),
                    TintChip(
                      icon: Icons.track_changes_rounded,
                      label: habit.scheduleLabel,
                      semanticsLabel: 'Schedule: ${_schedule(habit)}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MonthCalendar(habit: habit, store: store),
                const SizedBox(height: 16),
                Notes(habit: habit, store: store),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () {
                    store.setArchived(habit, true);
                    Navigator.pop(context);
                    toast(context, '"${habit.name}" archived',
                        undo: () => store.setArchived(habit, false));
                  },
                  // The app theme paints secondary buttons in soft flame,
                  // which is right everywhere except here — on a habit's own
                  // screen a brand-orange button is the one thing not wearing
                  // the habit's colour.
                  style: OutlinedButton.styleFrom(
                    backgroundColor: chipFill(context),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Archive'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    final index = store.remove(habit);
                    Navigator.pop(context);
                    toast(context, '"${habit.name}" deleted',
                        undo: () => store.insertAt(index, habit));
                  },
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

String _schedule(Habit h) {
  final freq = h.isWeekly ? '${h.perWeek}× per week' : 'Every day';
  return h.isCountable ? '$freq · ${h.target} per day' : freq;
}

void toast(BuildContext context, String message, {VoidCallback? undo}) {
  showToast(
    context,
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: undo == null ? 3 : 5),
      margin: const EdgeInsets.all(16),
      action:
          undo == null ? null : SnackBarAction(label: 'Undo', onPressed: undo),
    ),
  );
}

/// Shows [bar], and takes it away again when its time is up.
///
/// The timer is ours rather than ScaffoldMessenger's, unconditionally, because
/// the messenger's own auto-dismiss is conditional in ways a phone can trip
/// without telling anyone: it is skipped outright while the platform reports
/// accessible navigation, and it is only armed once the entrance animation
/// reports completion. Either way the toast sits there until something else
/// replaces it. Every toast here is an optional aside, so none of them get to
/// stay on screen.
///
/// It hides whatever is current rather than closing this controller: `close()`
/// asserts it is still the front of the queue, and a newer toast can have
/// replaced it by then. Cancelled when this one goes on its own, so it can
/// never take a later toast down early.
void showToast(BuildContext context, SnackBar bar) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  final shown = messenger.showSnackBar(bar);
  final timer = Timer(bar.duration, () {
    if (messenger.mounted) messenger.hideCurrentSnackBar();
  });
  shown.closed.whenComplete(timer.cancel);
}

/// One month at a time, Monday-first. The grid above shows the shape of a
/// year; this is where a specific day gets fixed — big enough to hit, and
/// labelled with the date you are actually looking for.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({super.key, required this.habit, required this.store});

  final Habit habit;
  final HabitStore store;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  /// How far back paging goes. Ten years is past any habit this app has
  /// history for, and a bounded count is what lets the pages be indexed from
  /// the oldest one rather than from an arbitrary zero.
  static const _months = 120;
  static const _last = _months - 1;

  /// One page per month, oldest first, so the current month is the last page
  /// and swiping right runs into the same dead end the Next button does.
  final _pages = PageController(initialPage: _last);
  var _page = _last;

  /// Six rows always, six cells of 40 with 2.5 either side. Fixed so the card
  /// does not change height as you page through the year — and so the pages
  /// have a height to be laid out in at all.
  static const _gridHeight = 6 * 45.0;

  DateTime _monthAt(int page) {
    final now = today();
    return DateTime(now.year, now.month - (_last - page));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _shift(int by) => _pages.animateToPage(
        (_page + by).clamp(0, _last),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final month = _monthAt(_page);
    final atLatest = _page == _last;

    return TintCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdays[i].substring(0, 3),
                      style: mono(11.5, color: scheme.secondary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Swipe as well as tap: the arrows are still there, and both drive
          // the same controller.
          SizedBox(
            height: _gridHeight,
            child: PageView.builder(
              controller: _pages,
              itemCount: _months,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, page) {
                final shown = _monthAt(page);
                // From the Monday on or before the 1st — see calendar_test.
                final first = startOfWeek(shown);
                return Column(
                  children: [
                    for (var row = 0; row < 6; row++)
                      Row(
                        children: [
                          for (var col = 0; col < 7; col++)
                            Expanded(
                              child: _DayCell(
                                habit: widget.habit,
                                store: widget.store,
                                day: shiftDays(first, row * 7 + col),
                                month: shown.month,
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardEdge(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 13, color: scheme.secondary),
                    const SizedBox(width: 7),
                    Text(
                      '${months[month.month - 1].substring(0, 3)} '
                      '${month.year}',
                      style: mono(12.5, color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              RoundIconButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => _shift(-1),
                tooltip: 'Previous month',
                size: 34,
              ),
              const SizedBox(width: 8),
              // Nothing to record in the future, so paging past this month is
              // a dead end rather than a disabled-looking button.
              Opacity(
                opacity: atLatest ? 0.35 : 1,
                child: IgnorePointer(
                  ignoring: atLatest,
                  child: RoundIconButton(
                    icon: Icons.chevron_right_rounded,
                    onPressed: () => _shift(1),
                    tooltip: 'Next month',
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.habit.isCountable
                ? 'Press and hold a day to set an amount'
                : 'Press and hold a day to add a note',
            style: text.labelSmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.habit,
    required this.store,
    required this.day,
    required this.month,
  });

  final Habit habit;
  final HabitStore store;
  final DateTime day;

  /// The month the calendar is showing — days spilling in from either side are
  /// still drawn, but recede.
  final int month;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = today();
    final outside = day.month != month;
    final future = day.isAfter(now);
    final isToday = day == now;
    final done = habit.isDoneOn(day);
    final partial = !done && habit.amountOn(day) > 0;
    final note = habit.noteOn(day);

    final cell = Container(
      height: 40,
      margin: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: done
            ? chipFill(context)
            : partial
                ? tint(context, 0.07)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        border:
            isToday ? Border.all(color: accentOf(context), width: 1.5) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: mono(
              13.5,
              color: outside || future
                  ? scheme.secondary.withValues(alpha: 0.45)
                  : done
                      ? onTint(context)
                      : scheme.onSurface,
              weight: done || isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          // A written day gets a dot under the number — the only place a note
          // is visible without opening it.
          if (note.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: accentOf(context),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );

    if (future) return Opacity(opacity: 0.5, child: cell);

    return Semantics(
      button: true,
      checked: done,
      label: '${shortDate(day)}, '
          '${habit.isCountable ? "${habit.amountOn(day)} of ${habit.target}" : done ? "done" : "not done"}'
          '${note.isEmpty ? "" : ". Note: $note"}',
      hint: done ? 'Mark as not done' : 'Mark as done',
      onTap: () => store.toggle(habit, day),
      onLongPress: () => showDaySheet(context, store, habit, day),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => store.toggle(habit, day),
        onLongPress: () => showDaySheet(context, store, habit, day),
        child: cell,
      ),
    );
  }
}
