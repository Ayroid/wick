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
    required this.position,
  });

  final HabitStore store;

  /// 0.0–2.0, straight from the PageController.
  final double position;

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
                  child: _Title(_titleFor(position.round())),
                ),
              ),
              IconButton(
                onPressed: () => showSettingsSheet(context, store),
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

/// Bottom navigation. Like the top bar it reads the *fractional* page
/// position, so the pill and the colours move with the swipe rather than
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        // The brand separates surfaces with light, not rules — so a shadow
        // thrown upward rather than a hairline border.
        boxShadow: [
          BoxShadow(
            color: isDark(context)
                ? const Color(0x66000000)
                : const Color(0x0F102A5C),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth / _items.length;

              return Stack(
                children: [
                  Positioned(
                    left: width * position + (width - 64) / 2,
                    top: 8,
                    // Slides *and* fades: the icons don't move, so a pill left
                    // at full strength between two tabs reads as a stray blob
                    // rather than an indicator.
                    child: Opacity(
                      opacity: (1 - (position - position.round()).abs() * 2)
                          .clamp(0.0, 1.0),
                      child: Container(
                        width: 64,
                        height: 30,
                        decoration: BoxDecoration(
                          color: flameSoftOf(context),
                          borderRadius: BorderRadius.circular(pill),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
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
              );
            },
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
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: colour),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
