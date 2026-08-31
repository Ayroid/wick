import 'package:flutter/material.dart';

import 'day_sheet.dart';
import 'detail.dart';
import 'home.dart';
import 'store.dart';
import 'theme.dart';
import 'wick.dart';

/// Every note ever written, newest day first. The detail screen already lists
/// one habit's notes; this is the same history read across all of them, which
/// is the version that reads like a diary rather than a footnote.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key, required this.store});

  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final days = notesByDay(store.habits);

        return Scaffold(
          // Header, tabs and the safe-area inset live in RootScreen's shared
          // top bar — this is only the page's content.
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                Expanded(
                  child: days.isEmpty
                      ? Center(
                          child: WickMessage(
                            pose: Wick.thinking,
                            size: 120,
                            headline: 'No notes yet',
                            body: 'Check a habit off and tap "Add note", or '
                                'hold any day to write about it.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: days.length,
                          itemBuilder: (context, i) =>
                              _DayGroup(store: store, day: days[i]),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// How many notes across all of [days] — the top bar's subtitle.
int countNotes(List<NoteDay> days) =>
    days.fold(0, (n, d) => n + d.notes.length);

/// One day's notes, however many habits they came from.
typedef NoteDay = ({String key, List<({Habit habit, String note})> notes});

/// Every note grouped by the day it belongs to, newest first. Archived habits
/// keep theirs — the history happened, whether or not the habit is still live.
List<NoteDay> notesByDay(List<Habit> habits) {
  final byDay = <String, List<({Habit habit, String note})>>{};
  for (final habit in habits) {
    habit.notes.forEach((key, note) {
      (byDay[key] ??= []).add((habit: habit, note: note));
    });
  }

  final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final k in keys) (key: k, notes: byDay[k]!)];
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.store, required this.day});

  final HabitStore store;
  final NoteDay day;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = parseDay(day.key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(_when(date), style: text.labelSmall),
          ),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Column(
              children: [
                for (final entry in day.notes)
                  InkWell(
                    onTap: () =>
                        showDaySheet(context, store, entry.habit, date),
                    onLongPress: () =>
                        openHabitDetail(context, store, entry.habit),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // A badge, not bare text: a day's notes are a
                              // mixed list, and the emoji is what you scan
                              // down the page to find the habit you want.
                              _HabitBadge(habit: entry.habit),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(entry.habit.name,
                                    style: text.titleSmall),
                              ),
                              DayMark(habit: entry.habit, day: date),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            // Indented to the badge's edge, so the note reads
                            // as belonging to the habit above it.
                            padding: const EdgeInsets.only(left: 38),
                            child: Text(entry.note, style: text.bodyMedium),
                          ),
                        ],
                      ),
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

class _HabitBadge extends StatelessWidget {
  const _HabitBadge({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    // Scoped so the badge is the habit's colour, the way its card is — this
    // list mixes every habit together and the mark is what tells them apart.
    return HabitAccent(
      color: habitColorAt(habit.color),
      child: HabitIcon(habit: habit, size: 28),
    );
  }
}

/// "Today" and "Yesterday" beat a date for the two days someone is most
/// likely to be looking at.
String _when(DateTime d) {
  final now = today();
  if (d == now) return 'Today';
  if (d == shiftDays(now, -1)) return 'Yesterday';
  return shortDate(d);
}
