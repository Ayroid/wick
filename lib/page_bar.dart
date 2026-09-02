import 'package:flutter/material.dart';

import 'analytics.dart';
import 'notes_screen.dart';
import 'settings.dart';
import 'store.dart';
import 'theme.dart';

/// The one fixed thing on screen. The title switches straight to whichever
/// page you have swiped to — no crossfade: two headlines sliding over each
/// other is motion for its own sake, and the page underneath already tells
/// you it moved.
///
/// Carries no navigation of its own — [PageTabs] at the bottom does that,
/// where a thumb already is.
class PageBar extends StatelessWidget {
  const PageBar({
    super.key,
    required this.store,
    required this.page,
  });

  final HabitStore store;

  /// The page that has landed — 0, 1 or 2.
  final int page;

  (String, String) _titleFor(int page) {
    switch (page) {
      case 0:
        return (greeting(), longDate(DateTime.now()));
      case 1:
        return ('Analytics', 'Last ${Analytics.defaultWindow} days');
      default:
        final days = notesByDay(store.habits);
        final n = countNotes(days);
        return (
          'Notes',
          days.isEmpty
              ? 'Nothing written yet'
              : '$n ${n == 1 ? "note" : "notes"} across ${days.length} '
                  '${days.length == 1 ? "day" : "days"}',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: _Title(_titleFor(page)),
                ),
              ),
              // Dashboard only: it switches how the habits below are drawn,
              // and there is nothing to switch on analytics or notes.
              if (page == 0) ...[
                LayoutSwitch(store: store),
                const SizedBox(width: 6),
              ],
              IconButton(
                onPressed: () => openSettings(context, store),
                icon: const Icon(Icons.settings_outlined, size: 22),
                color: scheme.secondary,
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
                tooltip: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cards-with-grids, or the compact table. Two glyphs in one well, the way
/// the reference bar reads — a switch between two views of the same habits,
/// not a control that does something.
class LayoutSwitch extends StatelessWidget {
  const LayoutSwitch({super.key, required this.store});

  final HabitStore store;

  static const _options = [
    (false, Icons.calendar_view_month_outlined, 'Card layout'),
    (true, Icons.view_list_outlined, 'Compact layout'),
  ];

  static const _slot = 34.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final at = store.compactLayout ? 1 : 0;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark(context) ? darkSunk : const Color(0xFFF0E9E1),
        borderRadius: BorderRadius.circular(pill),
      ),
      child: SizedBox(
        width: _slot * _options.length,
        height: _slot,
        child: Stack(
          children: [
            // The disc travels between the two glyphs; before, it appeared
            // under one and vanished from the other, which read as a flicker
            // rather than a switch.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: _slot * at,
              top: 0,
              child: Container(
                width: _slot,
                height: _slot,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              children: [
                for (final (compact, icon, label) in _options)
                  Semantics(
                    button: true,
                    selected: store.compactLayout == compact,
                    label: label,
                    excludeSemantics: true,
                    onTap: () => store.setCompactLayout(compact),
                    child: Tooltip(
                      message: label,
                      child: InkWell(
                        onTap: () => store.setCompactLayout(compact),
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: _slot,
                          height: _slot,
                          child: Icon(
                            icon,
                            size: 18,
                            color: store.compactLayout == compact
                                ? scheme.onSurface
                                : scheme.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.parts);

  final (String, String) parts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Text(parts.$1, maxLines: 1, style: text.headlineLarge),
        const SizedBox(height: 2),
        Text(parts.$2,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
      ],
    );
  }
}

/// Bottom navigation: a pill that floats over the page rather than a bar
/// ruled off from it. Like the top bar it reads the *fractional* page
/// position, so the lit disc slides under the thumb with the swipe instead of
/// jumping once a page lands — the two ends of the shell stay in step.
class PageTabs extends StatelessWidget {
  const PageTabs({
    super.key,
    required this.position,
    required this.onSelect,
  });

  final double position;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.check_circle_outline, 'Today'),
    (Icons.insights_outlined, 'Analytics'),
    (Icons.sticky_note_2_outlined, 'Notes'),
  ];

  /// One tap target, and the width of the disc that rides over them.
  static const _slot = 58.0;
  static const _inset = 5.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Shrink-wrapped, both ways: it is placed by the Align that hosts it, and
    // a Center here would float it up the middle of the page instead.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: UnconstrainedBox(
          child: Container(
            padding: const EdgeInsets.all(_inset),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(pill),
              // It floats now, so it needs a shadow on every side rather than
              // one thrown upward from an edge it no longer has.
              boxShadow: cardShadow(isDark(context)),
            ),
            child: SizedBox(
              width: _slot * _items.length,
              height: _slot,
              child: Stack(
                children: [
                  // Slides with the drag. No opacity trick: a disc halfway
                  // between two tabs reads as travel, which is what it is.
                  Positioned(
                    left: _slot * position,
                    top: 0,
                    child: Container(
                      width: _slot,
                      height: _slot,
                      decoration: BoxDecoration(
                        color: flameSoftOf(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        SizedBox(
                          width: _slot,
                          child: _Tab(
                            icon: _items[i].$1,
                            label: _items[i].$2,
                            // 0 at rest, 1 when this page fills the screen.
                            lit: (1 - (position - i).abs()).clamp(0.0, 1.0),
                            selected: position.round() == i,
                            onTap: () => onSelect(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.lit,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final double lit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = Color.lerp(scheme.secondary, flameOf(context), lit)!;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(child: Icon(icon, size: 22, color: colour)),
        ),
      ),
    );
  }
}
