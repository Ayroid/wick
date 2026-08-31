import 'package:flutter/material.dart';

import 'icons.dart';
import 'store.dart';
import 'theme.dart';
import 'wick.dart';

class HabitTemplate {
  const HabitTemplate(
    this.icon,
    this.name, {
    required this.color,
    this.target = 1,
    this.perWeek = 7,
  });

  /// A key into `iconByKey`.
  final String icon;
  final String name;

  /// Index into `habitColors`. Picked per template rather than left at the
  /// default so someone who takes four suggestions gets four distinguishable
  /// cards on their first run — grouped by theme, spread within each group.
  final int color;

  final int target;
  final int perWeek;

  String get schedule {
    if (target > 1) return '$target a day';
    return perWeek == 7 ? 'Every day' : '$perWeek× a week';
  }
}

/// Frequencies are deliberately realistic rather than aspirational — a gym
/// habit defaults to three times a week because seven is how people quit.
const starterGroups = <String, List<HabitTemplate>>{
  'Health': [
    HabitTemplate('dumbbell', 'Exercise', color: 5, perWeek: 3),
    HabitTemplate('footprints', 'Go for a walk', color: 6),
    HabitTemplate('standing', 'Stretch', color: 4),
    HabitTemplate('activity', 'Run', color: 7, perWeek: 3),
  ],
  'Food': [
    HabitTemplate('droplet', 'Drink water', color: 9, target: 8),
    HabitTemplate('salad', 'Eat vegetables', color: 5),
    HabitTemplate('chef', 'Cook at home', color: 2, perWeek: 4),
    HabitTemplate('beer', 'No alcohol', color: 0),
  ],
  'Mind': [
    HabitTemplate('book', 'Read', color: 10),
    HabitTemplate('flower', 'Meditate', color: 13),
    HabitTemplate('notebook', 'Journal', color: 12),
    HabitTemplate('graduation', 'Study', color: 11, perWeek: 5),
  ],
  'Life': [
    HabitTemplate('moon', 'Lights out by 11', color: 11),
    HabitTemplate('bed', 'Make the bed', color: 8),
    HabitTemplate('house', 'Tidy up', color: 7),
    HabitTemplate('phone', 'Call someone', color: 15, perWeek: 2),
  ],
  'Focus': [
    HabitTemplate('laptop', 'Deep work', color: 14, perWeek: 5),
    HabitTemplate('calendar', 'Plan tomorrow', color: 16),
    HabitTemplate('phone-mobile', 'No phone after dinner', color: 1),
  ],
};

/// The screen always pops itself once the chosen habits are added; [onDone] is
/// the extra bit that separates the first-run use (finish onboarding) from the
/// later one (nothing).
Future<void> openStarterTemplates(
  BuildContext context,
  HabitStore store, {
  VoidCallback? onDone,
  bool firstRun = false,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => StarterTemplatesScreen(
      store: store,
      onDone: onDone,
      firstRun: firstRun,
    ),
  ));
}

class StarterTemplatesScreen extends StatefulWidget {
  const StarterTemplatesScreen({
    super.key,
    required this.store,
    this.onDone,
    this.firstRun = false,
  });

  final HabitStore store;
  final VoidCallback? onDone;
  final bool firstRun;

  @override
  State<StarterTemplatesScreen> createState() => _StarterTemplatesScreenState();
}

class _StarterTemplatesScreenState extends State<StarterTemplatesScreen> {
  final _picked = <HabitTemplate>{};

  void _finish() {
    for (final t in _picked) {
      widget.store.add(t.name,
          icon: t.icon,
          color: t.color,
          target: t.target,
          perWeek: t.perWeek);
    }
    Navigator.of(context).pop();
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = _picked.length;

    return Scaffold(
      appBar: widget.firstRun
          ? null
          : AppBar(title: const Text('Suggestions')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, widget.firstRun ? 20 : 8, 20, 12),
                children: [
                  if (widget.firstRun)
                    Column(
                      children: [
                        const WickImage(Wick.thinking, size: 96),
                        const SizedBox(height: 14),
                        Text('What do you want to keep up?',
                            textAlign: TextAlign.center,
                            style: text.headlineLarge?.copyWith(fontSize: 23)),
                        const SizedBox(height: 6),
                        Text(
                          'Pick a few to start with. You can edit or remove '
                          'any of them later.',
                          textAlign: TextAlign.center,
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  for (final group in starterGroups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 6),
                      child: Text(group.key, style: text.labelSmall),
                    ),
                    ...group.value.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TemplateRow(
                            template: t,
                            selected: _picked.contains(t),
                            onTap: () => setState(() =>
                                _picked.contains(t) ? _picked.remove(t) : _picked.add(t)),
                          ),
                        )),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    // With nothing picked this still moves on, so the screen is
                    // never a dead end for someone who wants their own habits.
                    onPressed: _finish,
                    child: Text(switch (n) {
                      0 when widget.firstRun => 'I\'ll add my own',
                      0 => 'Done',
                      1 => 'Add 1 habit',
                      _ => 'Add $n habits',
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final HabitTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: selected ? successSoftOf(context) : null,
      child: Row(
        children: [
          Icon(iconFor(template.icon), size: 20, color: accentOf(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: text.titleMedium),
                const SizedBox(height: 1),
                Text(template.schedule, style: text.labelSmall),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: selected ? successOf(context) : Colors.transparent,
              shape: BoxShape.circle,
              border: selected
                  ? null
                  : Border.all(color: scheme.outline, width: 2),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 16, color: onSuccess)
                : null,
          ),
        ],
      ),
    );
  }
}
