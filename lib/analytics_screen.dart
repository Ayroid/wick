import 'package:flutter/material.dart';

import 'analytics.dart';
import 'grid.dart';
import 'icon_picker.dart';
import 'icons.dart';
import 'home.dart';
import 'store.dart';
import 'theme.dart';
import 'wick.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.store});

  final HabitStore store;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  /// Which habit the whole page is scoped to, or null for all of them.
  /// Held by id, not by object: an import replaces every habit, and a filter
  /// pointing at a freed one would silently show an empty page.
  String? _only;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final active =
            widget.store.habits.where((h) => !h.archived).toList();
        final picked = active.where((h) => h.id == _only).firstOrNull;
        final stats = Analytics(picked == null ? active : [picked]);

        return HabitAccent(
          // Filtered to one habit the page is *about* that habit, so it wears
          // its colour. Across all of them there is no one habit to speak for,
          // and it stays the brand flame.
          color: picked == null
              ? flameOf(context)
              : habitColorAt(picked.color),
          child: Scaffold(
          // Header, tabs and the safe-area inset all live in RootScreen's
          // shared top bar now — this is only the page's content.
          body: active.isEmpty
              ? Center(
                  child: WickMessage(
                    pose: Wick.thinking,
                    size: 120,
                    headline: 'Nothing to measure yet',
                    body: 'Add a habit and check it off — '
                        'the numbers show up here.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    // Only worth the row once there is a choice to make.
                    if (active.length > 1) ...[
                      _HabitFilter(
                        habits: active,
                        selected: _only,
                        onSelect: (id) => setState(() => _only = id),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _SummaryGrid(
                      stats: stats,
                      // The dashboard's own palette, in its own order. Scoped
                      // to one habit there is nothing to spread across four
                      // tiles — the page accent already is that habit.
                      palette: picked != null
                          ? const []
                          : [for (final h in active) habitColorAt(h.color)],
                    ),
                    const SizedBox(height: 12),
                    _TrendCard(stats: stats),
                    const SizedBox(height: 12),
                    _ConsistencyCard(stats: stats, single: picked),
                    const SizedBox(height: 12),
                    _WeekdayCard(stats: stats),
                    if (picked == null) ...[
                      const SizedBox(height: 12),
                      _PerHabitCard(stats: stats),
                    ],
                  ],
                ),
        ),
        );
      },
    );
  }
}

/// "All" plus one chip per habit. Scoping the page to a single habit is the
/// difference between "how am I doing" and "how is *this* going", and with
/// nine habits the averaged view answers neither.
class _HabitFilter extends StatelessWidget {
  const _HabitFilter({
    required this.habits,
    required this.selected,
    required this.onSelect,
  });

  final List<Habit> habits;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          _FilterChip(
            label: 'All',
            on: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final h in habits)
            HabitAccent(
              color: habitColorAt(h.color),
              child: _FilterChip(
                label: h.name,
                habit: h,
                on: selected == h.id,
                onTap: () => onSelect(h.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.on,
    required this.onTap,
    this.habit,
  });

  final String label;

  /// Null for the "All" chip, which stands for no habit in particular.
  final Habit? habit;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: on ? chipFill(context) : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(pill),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: habit == null ? 14 : 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(pill),
                border: Border.all(
                  color: on ? tint(context, 0.4) : Colors.transparent,
                ),
              ),
              // A habit chip is its mark alone, in the habit's own colour —
              // the row is scanned, not read, and nine names in a row is a
              // wall of text where nine colours is a palette. "All" has no
              // mark, so it keeps its word.
              child: habit == null
                  ? Text(
                      label,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: on ? onTint(context) : scheme.secondary,
                      ),
                    )
                  : habit!.icon.isEmpty
                      ? Text(
                          habit!.emoji.isEmpty ? defaultEmoji : habit!.emoji,
                          style: const TextStyle(fontSize: 15),
                        )
                      : Icon(
                          iconFor(habit!.icon),
                          size: 18,
                          // Its colour in both states: unselected is what
                          // tells one chip from the next.
                          color: accentOf(context),
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four figures, two by two. A single row of three squeezed a three-digit
/// number into 90 px; the reference gives each one a tile it can breathe in,
/// with the glyph in the corner saying what kind of number it is.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats, this.palette = const []});

  final Analytics stats;

  /// The habits' own colours, in their own order, for the unfiltered page —
  /// four aggregate numbers have no habit to belong to, but the page still
  /// reads in the palette the dashboard uses rather than four orange tiles.
  /// Empty when the page is scoped to one habit: then every tile is that
  /// habit's colour, which the page accent already provides.
  final List<Color> palette;

  /// Cycles, so one habit colours all four and nine colour the first four.
  Widget _tinted(int i, Widget tile) => palette.isEmpty
      ? tile
      : HabitAccent(color: palette[i % palette.length], child: tile);

  @override
  Widget build(BuildContext context) {
    final best = stats.longestActiveStreak;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _tinted(
                0,
                _Stat(
                icon: Icons.percent_rounded,
                value: '${(stats.completionRate * 100).round()}',
                label: 'Completion',
                caption: 'last ${stats.window} days',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tinted(
                1,
                _Stat(
                icon: Icons.check_rounded,
                value: '${stats.totalCheckOffs}',
                label: 'Check-offs',
                caption: 'all time',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tinted(
                2,
                _Stat(
                icon: Icons.local_fire_department_rounded,
                value: best == null ? '0' : '${best.$2}',
                label: 'Best run',
                caption: best == null || best.$2 == 0
                    ? 'none active'
                    : (best.$1.isWeekly ? 'weeks' : 'days'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tinted(
                3,
                _Stat(
                icon: Icons.auto_awesome_rounded,
                value: '${stats.perfectDays}',
                label: 'Clean days',
                caption: 'of ${stats.measuredDays} measured',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final String value;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      label: '$label: $value, $caption',
      excludeSemantics: true,
      child: TintCard(
        // White under the number, colour only at the edge and on the badge:
        // four tinted grounds side by side turned the top of the page into a
        // swatch chart, and the figures are what the page is for.
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chipFill(context),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: accentOf(context)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              style: text.headlineLarge?.copyWith(fontSize: 30, height: 1),
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                style: text.titleMedium?.copyWith(fontSize: 14)),
            Text(caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mono(11, color: Theme.of(context).colorScheme.secondary)),
          ],
        ),
      ),
    );
  }
}

/// Completion by week. Everything else on this page is a snapshot — this is
/// the only card that answers "is it getting better or worse", which is the
/// question a stats page exists for.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.stats});

  final Analytics stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = stats.weeklyTrend();

    // Two points is a line, one is a dot pretending to be a trend. Below that
    // the card says so rather than drawing a shape with no meaning.
    if (points.length < 3) {
      return TintCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trend', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'A few weeks of history and the shape of it shows up here.',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      );
    }

    final latest = points.last.$2;
    final previous = points[points.length - 2].$2;
    final change = ((latest - previous) * 100).round();

    return TintCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trend', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Completion by week, last ${points.length}',
                        style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              TintChip(
                icon: change > 0
                    ? Icons.trending_up_rounded
                    : change < 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded,
                label: change == 0
                    ? 'Level'
                    : '${change > 0 ? "+" : ""}$change',
                dim: change == 0,
                semanticsLabel: change == 0
                    ? 'Level with last week'
                    : '${change.abs()} points '
                        '${change > 0 ? "up on" : "down on"} last week',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label: 'Weekly completion, oldest to newest: '
                '${points.map((p) => "${(p.$2 * 100).round()} percent").join(", ")}',
            excludeSemantics: true,
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendPainter(
                  values: [for (final p in points) p.$2],
                  line: accentOf(context),
                  grid: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.18),
                  dark: isDark(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_weekLabel(points.first.$1),
                  style: mono(10.5, color: gridLabel(context))),
              Text('now', style: mono(10.5, color: gridLabel(context))),
            ],
          ),
        ],
      ),
    );
  }

  String _weekLabel(DateTime monday) =>
      '${months[monday.month - 1].substring(0, 3)} ${monday.day}';
}

/// An area under a line, on a 0/50/100 rule. Hand-painted rather than a chart
/// package: it is forty lines, and a dependency would be the larger thing.
class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.line,
    required this.grid,
    required this.dark,
  });

  final List<double> values;
  final Color line;
  final Color grid;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    // Room at the top so a 100% week's dot is not clipped by the card edge.
    const inset = 5.0;
    final h = size.height - inset * 2;
    double x(int i) => size.width * (i / (values.length - 1));
    double y(double v) => inset + h * (1 - v.clamp(0.0, 1.0));

    final rule = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [0.0, 0.5, 1.0]) {
      canvas.drawLine(Offset(0, y(v)), Offset(size.width, y(v)), rule);
    }

    final path = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }

    // The fill is the same path closed down to the baseline, so the line and
    // its shading can never disagree about where the data is.
    final fill = Path.from(path)
      ..lineTo(x(values.length - 1), y(0))
      ..lineTo(x(0), y(0))
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            line.withValues(alpha: dark ? 0.34 : 0.28),
            line.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Only the most recent week is marked. A dot on every point turns a
    // twelve-week line into beads.
    canvas.drawCircle(
      Offset(x(values.length - 1), y(values.last)),
      3.6,
      Paint()..color = line,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.line != line || old.dark != dark;
}

/// Every habit collapsed into one grid: the stronger the cell, the bigger the
/// share of that day's habits you finished. Scoped to one habit it is that
/// habit's own history, which is the same picture the dashboard card shows.
class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.stats, this.single});

  final Analytics stats;

  /// Non-null when the page is filtered — the card then titles itself for that
  /// habit rather than claiming to span all of them.
  final Habit? single;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TintCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Consistency', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            single == null
                ? 'Share of each day\'s habits completed'
                : 'Every day of ${single!.name}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 16),
          GridFrame(
            size: 11,
            gap: 3.5,
            showMonths: true,
            showDays: true,
            label: (days) {
              final measured = days.where(
                  (d) => !d.isAfter(today()) && stats.hasAnyHabitOn(d));
              final perfect =
                  measured.where((d) => stats.dayScore(d) == 1).length;
              return measured.isEmpty
                  ? 'Consistency: nothing recorded yet'
                  : 'Consistency over the last ${measured.length} days: '
                      '$perfect fully completed';
            },
            cell: (day) => _ScoreCell(stats: stats, day: day),
          ),
          const SizedBox(height: 14),
          const _Legend(),
        ],
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.stats, required this.day});

  final Analytics stats;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = today();
    final future = day.isAfter(now);
    final untracked = !future && !stats.hasAnyHabitOn(day);

    return Tooltip(
      message: future || untracked
          ? shortDate(day)
          : '${shortDate(day)} — ${(stats.dayScore(day) * 100).round()}%',
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: future
              ? tint(context, isDark(context) ? 0.06 : 0.05)
              : untracked
                  // Before any habit existed: drawn, but visibly not a miss.
                  ? Colors.transparent
                  : shadeFor(stats.dayScore(day), context),
          border: untracked
              ? Border.all(color: cellEmpty(context))
              : day == now
                  ? Border.all(color: accentOf(context), width: 1.4)
                  : null,
          borderRadius: BorderRadius.circular(3.5),
        ),
      ),
    );
  }
}

/// One habit's completion bar. Its own widget so it builds *below* the
/// [HabitAccent] wrapping it — read from the card's context instead, every bar
/// on the page comes out the page's flame rather than the habit's colour.
class _HabitRate extends StatelessWidget {
  const _HabitRate({
    required this.habit,
    required this.rate,
    required this.days,
  });

  final Habit habit;
  final double rate;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${habit.name}: ${(rate * 100).round()} percent '
          'over the last $days days',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HabitIcon(habit: habit, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(rate * 100).round()}%',
                style: mono(13,
                    color: theme.colorScheme.onSurface,
                    weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(pill),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 7,
              backgroundColor: cellEmpty(context),
              valueColor: AlwaysStoppedAnimation(accentOf(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four steps rather than a continuous ramp — adjacent days stay
/// distinguishable, which a smooth gradient at this cell size does not.
Color shadeFor(double score, BuildContext c) {
  final base = accentOf(c);
  if (score <= 0) return cellEmpty(c);
  if (score < 0.34) return Color.lerp(cellEmpty(c), base, 0.3)!;
  if (score < 0.67) return Color.lerp(cellEmpty(c), base, 0.58)!;
  if (score < 1) return Color.lerp(cellEmpty(c), base, 0.8)!;
  return base;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('None', style: mono(10.5, color: gridLabel(context))),
          const SizedBox(width: 6),
          for (final s in [0.0, 0.3, 0.6, 0.9, 1.0])
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: shadeFor(s, context),
                  borderRadius: BorderRadius.circular(3.5),
                ),
              ),
            ),
          const SizedBox(width: 3),
          Text('All', style: mono(10.5, color: gridLabel(context))),
        ],
      ),
    );
  }
}

class _WeekdayCard extends StatelessWidget {
  const _WeekdayCard({required this.stats});

  final Analytics stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rates = stats.byWeekday;
    final spread = stats.bestAndWorstWeekday;

    return TintCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By weekday', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            spread == null
                ? 'Fairly even across the week'
                : 'Strongest on ${weekdays[spread.$1 - 1]}, '
                    'weakest on ${weekdays[spread.$2 - 1]}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 18),
          SizedBox(
            // value label + bar + weekday label, at the font's line height.
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var wd = 1; wd <= 7; wd++)
                  _Bar(
                    label: weekdayShort[wd - 1],
                    value: rates[wd] ?? 0,
                    best: spread != null && spread.$1 == wd,
                    worst: spread != null && spread.$2 == wd,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.best,
    required this.worst,
  });

  final String label;
  final double value;
  final bool best;
  final bool worst;

  static const _maxHeight = 62.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$label: ${(value * 100).round()} percent'
          '${best ? ", strongest day" : worst ? ", weakest day" : ""}',
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${(value * 100).round()}',
            // Not the chart yellow: this is text on cream, where yellow is
            // unreadable. Weight and the full-strength foreground carry it.
            style: mono(
              10.5,
              color: best
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.secondary,
              weight: best ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // The whole column is drawn, with the filled part inside it, so the
          // bars read against a common ceiling instead of floating.
          Container(
            width: 26,
            height: _maxHeight,
            alignment: Alignment.bottomCenter,
            decoration: BoxDecoration(
              color: cellEmpty(context),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Container(
              width: 26,
              // A zero-rate weekday still shows a sliver, so the bar reads as
              // "measured and empty" rather than "missing".
              height: (value * _maxHeight).clamp(3.0, _maxHeight),
              decoration: BoxDecoration(
                color: best
                    ? accentOf(context)
                    : accentOf(context).withValues(
                        alpha: isDark(context) ? 0.5 : 0.42),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: mono(
              10.5,
              color: best ? flameOf(context) : theme.colorScheme.secondary,
              weight: best ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerHabitCard extends StatelessWidget {
  const _PerHabitCard({required this.stats});

  final Analytics stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = stats.perHabit;

    return TintCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By habit', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text('Completion over the last ${stats.window} days',
              style: theme.textTheme.labelSmall),
          const SizedBox(height: 16),
          for (final (habit, rate) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: HabitAccent(
                color: habitColorAt(habit.color),
                child: _HabitRate(habit: habit, rate: rate, days: stats.window),
              ),
            ),
        ],
      ),
    );
  }
}
