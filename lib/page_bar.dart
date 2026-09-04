import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  const PageBar({super.key, required this.store, required this.page});

  final HabitStore store;

  /// The page that has landed — 0, 1 or 2.
  final int page;

  (String, String) _titleFor(int page) {
    switch (page) {
      case 0:
        return (greeting(), longDate(today()));
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
                child: SizedBox(height: 58, child: _Title(_titleFor(page))),
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
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
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
        Text(
          parts.$2,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// Bottom navigation: a pill that floats over the page rather than a bar
/// ruled off from it. Like the top bar it reads the *fractional* page
/// position, so the lit disc slides under the thumb with the swipe instead of
/// jumping once a page lands — the two ends of the shell stay in step.
/// One destination in the shell.
typedef TabSpec = ({String label, IconData icon});

const shellTabs = <TabSpec>[
  (label: 'Today', icon: LucideIcons.circleCheck),
  (label: 'Analytics', icon: LucideIcons.chartPie),
  (label: 'Notes', icon: LucideIcons.notebookPen),
];

/// How tall the floating tab pill stands: the tab itself plus the track's
/// padding on both sides.
///
/// Exported because the add button sits beside it and has to match. Two
/// hand-tuned numbers that must agree is a pair that drifts the first time
/// either is touched.
const tabHeight = 44.0;
const tabInset = 5.0;
const tabBarHeight = tabHeight + tabInset * 2;

/// The floating tab pill.
///
/// A `Stack` overlay rather than a `bottomNavigationBar`, which would reserve a
/// strip of the screen for chrome on every page. [position] is the PageView's
/// fractional offset, so the selected tab widens with the swipe instead of
/// snapping when it settles.
///
/// Shared shape with Penny: the two apps are the same app wearing a different
/// colour, and a nav bar that differs between them is the most visible place
/// for that claim to fall over. This one used to be three circular slots with a
/// disc riding over them; it is a pill whose selected tab opens to show its
/// label, which is what Penny does and what makes the label readable at all
/// rather than living only in a tooltip.
class PageTabs extends StatelessWidget {
  const PageTabs({super.key, required this.position, required this.onSelect});

  /// Listened to here rather than above, so a swipe repaints the pill and not
  /// the three pages of habit cards behind it.
  final ValueListenable<double> position;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.bottomCenter,
      // Above the gesture bar, not under it. The shell is a bare Stack over the
      // whole screen, so without this the pill sits in the strip the system
      // reserves for its own back-swipe.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark(context) ? darkCard : Colors.white,
              borderRadius: BorderRadius.circular(pill),
              boxShadow: cardShadow(isDark(context)),
            ),
            clipBehavior: Clip.antiAlias,
            // The pill floats over pages that bring their own Scaffolds; it has
            // no Material of its own, and every tab is an InkWell.
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(tabInset),
                child: ValueListenableBuilder<double>(
                  valueListenable: position,
                  builder: (context, value, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < shellTabs.length; i++)
                        _Tab(
                          spec: shellTabs[i],
                          // How selected this tab is, 0 to 1. Mid-swipe both
                          // neighbours are partly lit, which is what makes the
                          // pill track the finger.
                          //
                          // `clamp` does not tame a NaN — it returns one — and a
                          // NaN weight becomes a NaN width. `PageController.page`
                          // is NaN before first layout, so this does not trust
                          // what it is handed.
                          weight: value.isNaN
                              ? (i == 0 ? 1.0 : 0.0)
                              : (1 - (value - i).abs()).clamp(0.0, 1.0),
                          onTap: () => onSelect(i),
                          scheme: scheme,
                        ),
                    ],
                  ),
                ),
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
    required this.spec,
    required this.weight,
    required this.onTap,
    required this.scheme,
  });

  final TabSpec spec;
  final double weight;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final accent = flameOf(context);
    // Colour is never the only signal: the label also appears, and the glyph
    // brightens, as a tab becomes selected.
    final fill = accent.withValues(alpha: weight);
    final ink = Color.lerp(scheme.secondary, onAccent(context), weight)!;

    return Semantics(
      button: true,
      selected: weight > 0.5,
      label: spec.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: spec.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(pill),
          child: Container(
            height: tabHeight,
            constraints: const BoxConstraints(minWidth: 48),
            padding: EdgeInsets.symmetric(horizontal: 14 + 6 * weight),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(spec.icon, size: 19, color: ink),
                // The label only exists once the tab is more than half
                // selected, so three labels never compete for the pill's width.
                ClipRect(
                  child: Align(
                    widthFactor: weight,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        spec.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
