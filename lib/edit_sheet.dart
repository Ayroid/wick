import 'package:flutter/material.dart';

import 'icon_picker.dart';
import 'icons.dart';
import 'reminders.dart';
import 'store.dart';
import 'theme.dart';

/// One sheet for both create and edit — [habit] null means create.
Future<void> showEditSheet(
  BuildContext context,
  HabitStore store, [
  Habit? habit,
]) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EditSheet(store: store, habit: habit),
  );
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.store, this.habit});

  final HabitStore store;
  final Habit? habit;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.habit?.name ?? '');
  late final _description =
      TextEditingController(text: widget.habit?.description ?? '');
  late var _emoji = widget.habit?.emoji ?? '';
  late var _icon = widget.habit?.icon ?? defaultIcon;
  late var _color = widget.habit?.color ?? defaultHabitColor;
  late var _target = widget.habit?.target ?? 1;
  late var _perWeek = widget.habit?.perWeek ?? 7;
  late var _reminder = widget.habit?.reminder;
  var _denied = false;

  /// Open by default; the disclosure still collapses it.
  var _advanced = true;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final description = _description.text.trim();
    if (widget.habit == null) {
      widget.store.add(name,
          description: description,
          emoji: _emoji,
          icon: _icon,
          color: _color,
          target: _target,
          perWeek: _perWeek,
          reminder: _reminder);
    } else {
      widget.store.edit(widget.habit!,
          name: name,
          description: description,
          emoji: _emoji,
          icon: _icon,
          color: _color,
          target: _target,
          perWeek: _perWeek,
          reminder: _reminder,
          clearReminder: _reminder == null);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  widget.habit == null ? 'New Habit' : 'Edit Habit',
                  style: text.titleLarge,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RoundIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cancel',
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: HabitAccent(
              color: habitColorAt(_color),
              child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IconHero(
                    icon: _icon,
                    emoji: _emoji,
                    onChanged: (choice) => setState(() {
                      _icon = choice.icon;
                      _emoji = choice.emoji;
                    }),
                  ),
                  const SizedBox(height: 20),
                  _Labelled(
                    label: 'NAME',
                    child: TextField(
                      controller: _name,
                      autofocus: widget.habit == null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          const InputDecoration(hintText: 'Read 20 pages'),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Labelled(
                    label: 'DESCRIPTION',
                    child: TextField(
                      controller: _description,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          hintText: 'Twenty pages before bed'),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Labelled(
                    label: 'COLOR',
                    child: _ColorPicker(
                      selected: _color,
                      onSelect: (i) => setState(() => _color = i),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Disclosure(
                    open: _advanced,
                    onTap: () => setState(() => _advanced = !_advanced),
                  ),
                  if (_advanced) ...[
                    const SizedBox(height: 18),
                    _Field(
                      label: 'How often',
                      hint: _perWeek == 7
                          ? 'Every day'
                          : '$_perWeek ${_perWeek == 1 ? "day" : "days"} a week — streaks count weeks',
                      child: AmountStepper(
                        value: _perWeek,
                        min: 1,
                        max: 7,
                        format: (v) => v == 7 ? 'Daily' : '$v× / week',
                        onChanged: (v) => setState(() => _perWeek = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      label: 'Daily amount',
                      hint: _target == 1
                          ? 'A simple check-off'
                          : 'Counts up to $_target each day',
                      child: AmountStepper(
                        value: _target,
                        min: 1,
                        max: 99,
                        format: (v) => v == 1 ? 'Check off' : '$v per day',
                        onChanged: (v) => setState(() => _target = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      label: 'Reminder',
                      hint: _denied
                          ? 'Notifications are off for Wick — turn them on in Settings'
                          : _reminder == null
                              ? 'No nudge'
                              : 'Only if it is still unchecked by then',
                      child: _ReminderButton(
                        minutes: _reminder,
                        onChanged: (v) => setState(() => _reminder = v),
                        onDenied: () => setState(() => _denied = true),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ),
          ),
          // Pinned rather than scrolled away: the reference keeps Save on
          // screen the whole time, and it is the only way out that keeps work.
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 10, 20, 10 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: scheme.outline)),
            ),
            child: ListenableBuilder(
              listenable: _name,
              builder: (context, _) => FilledButton(
                onPressed: _name.text.trim().isEmpty ? null : _save,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(pill)),
                ),
                child: const Text('Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The chosen icon, big, over a faded wall of the ones it was chosen from.
/// The backdrop is decoration and a hint at once: it says the disc is a
/// picker without needing a caption to say so.
class _IconHero extends StatelessWidget {
  const _IconHero({
    required this.icon,
    required this.emoji,
    required this.onChanged,
  });

  final String icon;
  final String emoji;
  final ValueChanged<IconChoice> onChanged;

  /// Enough of the set to fill the backdrop at any width. Taken from across
  /// the groups rather than the first N, so the wall does not read as one
  /// category.
  static final _wall = () {
    final all = iconByKey.values.toList();
    return [for (var i = 0; i < all.length; i += 3) all[i]];
  }();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Clipped rather than fitted: the wall is a texture, and a run that
          // ends mid-row at the bottom reads as a layout accident. Letting it
          // overflow past both edges and cutting it reads as a field that
          // carries on.
          ExcludeSemantics(
            child: ClipRect(
              child: OverflowBox(
                maxHeight: double.infinity,
                child: Opacity(
                  opacity: isDark(context) ? 0.14 : 0.20,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      for (final glyph in _wall)
                        Icon(glyph, size: 19, color: accentOf(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // A disc of the sheet's own ground behind the pick, so the wall
          // reads as backdrop rather than crowding it.
          Semantics(
            button: true,
            label: 'Icon',
            hint: 'Change',
            excludeSemantics: true,
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  final picked = await showIconPicker(context,
                      icon: icon, emoji: emoji);
                  if (picked != null) onChanged(picked);
                },
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: chipFill(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: tint(context, 0.35), width: 1.5),
                  ),
                  child: icon.isEmpty
                      ? Text(
                          emoji.isEmpty ? defaultEmoji : emoji,
                          style: const TextStyle(fontSize: 38),
                        )
                      : Icon(iconFor(icon),
                          size: 40, color: accentOf(context)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference's swatch grid: three rows of seven, the pick ringed with a
/// gap so the ring reads as a ring rather than as a thicker swatch.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Seven across, whatever the screen — the grid is the reference's and
        // reflowing it to six on a narrow phone would lose that.
        const columns = 7;
        const gap = 8.0;
        final side = (box.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < habitColors.length; i++)
              _Swatch(
                colour: habitColors[i].value,
                name: habitColors[i].name,
                side: side,
                on: i == selected,
                onTap: () => onSelect(i),
              ),
          ],
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colour,
    required this.name,
    required this.side,
    required this.on,
    required this.onTap,
  });

  final Color colour;
  final String name;
  final double side;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: side,
          height: side,
          child: Container(
            // The ring is drawn on the outside with the sheet's own ground
            // between it and the swatch, so a dark swatch and its ring do not
            // merge into one fatter square.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(side * 0.32),
              border: Border.all(
                color: on ? colour : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(side * 0.24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small caps label over a field, the way the reference titles every input.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 7),
          child: Text(
            label,
            style: mono(11.5,
                color: Theme.of(context).colorScheme.secondary,
                weight: FontWeight.w600,
                spacing: 1),
          ),
        ),
        child,
      ],
    );
  }
}

/// "Advanced Options" with a rule running out to either side.
class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.secondary;
    final rule = Divider(color: muted.withValues(alpha: 0.25), height: 1);

    return Semantics(
      button: true,
      expanded: open,
      label: 'Advanced options',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: rule),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Advanced Options',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(width: 4),
                    Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: muted,
                    ),
                  ],
                ),
              ),
              Expanded(child: rule),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.hint, required this.child});

  final String label;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            child,
          ],
        ),
        const SizedBox(height: 4),
        Text(hint, style: TextStyle(fontSize: 12, color: muted)),
      ],
    );
  }
}

/// Shared with the day sheet — the same control sets a habit's daily target
/// and the amount actually recorded on a day.
class AmountStepper extends StatelessWidget {
  const AmountStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final String Function(int) format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 92),
            alignment: Alignment.center,
            child: Text(format(value), style: const TextStyle(fontSize: 13)),
          ),
          _StepButton(
            icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? scheme.outline : scheme.onSurface,
        ),
      ),
    );
  }
}

/// Off, or a time. Permission is asked for at the moment someone actually
/// wants a reminder, not on first launch when it means nothing to them.
class _ReminderButton extends StatelessWidget {
  const _ReminderButton({
    required this.minutes,
    required this.onChanged,
    required this.onDenied,
  });

  final int? minutes;
  final ValueChanged<int?> onChanged;
  final VoidCallback onDenied;

  Future<void> _pick(BuildContext context) async {
    if (minutes != null) {
      onChanged(null); // tapping a set time clears it
      return;
    }
    if (!await reminders.requestPermission()) {
      onDenied();
      return;
    }
    if (!context.mounted) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked != null) onChanged(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = minutes != null;

    return OutlinedButton.icon(
      onPressed: () => _pick(context),
      icon: Icon(
        on ? Icons.notifications_active_outlined : Icons.notifications_none,
        size: 16,
      ),
      label: Text(
        on
            ? TimeOfDay(hour: minutes! ~/ 60, minute: minutes! % 60)
                .format(context)
            : 'Off',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: on ? flameOf(context) : scheme.onSurface,
        backgroundColor: Colors.transparent,
        // The app theme makes outlined buttons full-width; this one sits
        // inline next to a label, so it has to shrink-wrap.
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(
            fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w600),
        side: BorderSide(color: on ? flameOf(context) : scheme.outline),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}
