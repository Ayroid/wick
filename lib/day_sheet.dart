import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'edit_sheet.dart';
import 'home.dart';
import 'store.dart';
import 'theme.dart';

/// Everything about one day, in one sheet: how much was actually recorded, and
/// what happened. Tapping a dot or a heatmap cell can only ever mean "all of
/// it" — this is where 5 of 8 glasses goes.
///
/// An empty note field is how a note is deleted, so there's no separate
/// destructive control.
Future<void> showDaySheet(
  BuildContext context,
  HabitStore store,
  Habit habit,
  DateTime day,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // The card is drawn here rather than by the sheet, so it can float clear
    // of all four edges instead of growing out of the bottom one.
    backgroundColor: Colors.transparent,
    elevation: 0,
    // Above the sheet, not inside it: the sheet's own build reads the accent
    // for the note field's border, so the scope has to be over that context.
    builder: (context) => HabitAccent(
      color: habitColorAt(habit.color),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          // Clear of the keyboard when it is up, of the gesture bar when it
          // is not.
          12 +
              math.max(
                MediaQuery.viewInsetsOf(context).bottom,
                MediaQuery.viewPaddingOf(context).bottom,
              ),
        ),
        child: Material(
          color:
              Theme.of(context).bottomSheetTheme.backgroundColor ??
              Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: _DaySheet(store: store, habit: habit, day: day),
        ),
      ),
    ),
  );
}

class _DaySheet extends StatefulWidget {
  const _DaySheet({
    required this.store,
    required this.habit,
    required this.day,
  });

  final HabitStore store;
  final Habit habit;
  final DateTime day;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late final _text = TextEditingController(
    text: widget.habit.noteOn(widget.day),
  );
  late var _amount = widget.habit.amountOn(widget.day);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.habit.isCountable) {
      widget.store.setAmount(widget.habit, widget.day, _amount);
    }
    widget.store.setNote(widget.habit, widget.day, _text.text);
    Navigator.pop(context);
  }

  /// The check control writes straight through — the sheet's Save is for the
  /// note, and a day marked done should stay done if the sheet is dismissed.
  void _toggle() => setState(() {
    widget.store.toggle(widget.habit, widget.day);
    _amount = widget.habit.amountOn(widget.day);
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final had = widget.habit.noteOn(widget.day).isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The habit, the day, and the day's own check — the same header
          // the dashboard card carries, so the sheet reads as that card
          // opened rather than as a form about it.
          Row(
            children: [
              HabitIcon(habit: widget.habit),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.day == today() ? 'Today' : shortDate(widget.day),
                      style: text.labelSmall?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              HabitMark(habit: widget.habit, day: widget.day, onTap: _toggle),
            ],
          ),
          if (widget.habit.isCountable) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Amount', style: text.titleSmall),
                AmountStepper(
                  value: _amount,
                  min: 0,
                  max: widget.habit.target,
                  format: (v) => '$v of ${widget.habit.target}',
                  onChanged: (v) => setState(() => _amount = v),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // No 'Notes' heading: the hint says what the box is for, and the
          // reference's sheet is the field and the button, nothing else.
          TextField(
            controller: _text,
            autofocus: !widget.habit.isCountable,
            maxLines: 5,
            minLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'What went well? What got in the way?',
              // The cap still holds; it just stops announcing itself under
              // a box nobody is going to fill.
              counterText: '',
              enabledBorder: noteBorder(tint(context, 0.45)),
              focusedBorder: noteBorder(accentOf(context), width: 1.5),
            ),
          ),
          const SizedBox(height: 4),
          // The label tracks the field: emptying an existing note is how you
          // delete it, so the button has to say so before you press it.
          ListenableBuilder(
            listenable: _text,
            builder: (context, _) => FilledButton(
              onPressed: _save,
              // The habit's own colour, with whichever ink actually reads on
              // it. A squircle rather than a pill: the same corner the icon
              // tile and the check control are drawn with, one size up.
              style: FilledButton.styleFrom(
                backgroundColor: accentOf(context),
                foregroundColor: onAccent(context),
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
              child: Text(
                !widget.habit.isCountable && had && _text.text.trim().isEmpty
                    ? 'Remove'
                    : 'Save',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Notes are useless if the only way back to one is remembering which cell it
/// was on, so every note also lists here, newest first.
class Notes extends StatelessWidget {
  const Notes({super.key, required this.habit, required this.store});

  final Habit habit;
  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final days = habit.notedDays;

    // Empty is the common case on a young habit, and an invitation reads
    // better there than a card with a heading and nothing under it.
    if (days.isEmpty) {
      return TintCard(
        onTap: () => showDaySheet(context, store, habit, today()),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chipFill(context),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 22,
                color: accentOf(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No notes yet',
                    style: text.titleMedium?.copyWith(fontSize: 15.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'What went well? What got in the way?',
                    style: text.labelSmall?.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_circle_outline_rounded,
              size: 22,
              color: accentOf(context),
            ),
          ],
        ),
      );
    }

    return TintCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes', style: text.titleMedium?.copyWith(fontSize: 15.5)),
          const SizedBox(height: 2),
          for (final key in days)
            InkWell(
              onTap: () => showDaySheet(context, store, habit, parseDay(key)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The day's state sits with its note, so the list reads as
                    // a history rather than a wall of text — a note on a day
                    // that was missed means something different.
                    Row(
                      children: [
                        DayMark(habit: habit, day: parseDay(key)),
                        const SizedBox(width: 6),
                        Text(
                          shortDate(parseDay(key)),
                          style: mono(
                            11.5,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(habit.notes[key]!, style: text.bodyMedium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Done, part-way, or missed — at the size of a bullet point. Shared with the
/// notes screen so a note reads the same wherever it's listed.
class DayMark extends StatelessWidget {
  const DayMark({super.key, required this.habit, required this.day});

  final Habit habit;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final done = habit.isDoneOn(day);
    final amount = habit.amountOn(day);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: done
          ? 'done'
          : amount > 0
          ? '$amount of ${habit.target}'
          : 'not done',
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: done
              ? accentOf(context)
              : amount > 0
              ? tint(context, 0.35)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: done || amount > 0
              ? null
              : Border.all(color: scheme.outline, width: 1.5),
        ),
        child: done
            ? Icon(Icons.check_rounded, size: 10, color: onAccent(context))
            : null,
      ),
    );
  }
}
