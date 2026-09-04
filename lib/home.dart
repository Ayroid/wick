import 'package:flutter/material.dart';

import 'compact_list.dart';
import 'day_sheet.dart';
import 'clock.dart';
import 'detail.dart';
import 'page_bar.dart';
import 'edit_sheet.dart';
import 'grid.dart';
import 'icon_picker.dart';
import 'icons.dart';
import 'store.dart';
import 'templates.dart';
import 'theme.dart';
import 'wick.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final HabitStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    return Scaffold(
      floatingActionButton: ListenableBuilder(
        listenable: store,
        builder: (context, _) => store.visible.isEmpty
            ? const SizedBox.shrink()
            // Sized to the tab pill beside it. A 56px default FAB next to a
            // 54px bar reads as a mistake at a glance, and the two are the
            // only two things floating over the page.
            : Theme(
                data: Theme.of(context).copyWith(
                  floatingActionButtonTheme: const FloatingActionButtonThemeData(
                    sizeConstraints: BoxConstraints.tightFor(
                      width: tabBarHeight,
                      height: tabBarHeight,
                    ),
                  ),
                ),
                child: FloatingActionButton(
                  onPressed: () => showEditSheet(context, store),
                  tooltip: 'New habit',
                  backgroundColor: flameOf(context),
                  // Computed, not white: the flame is a mid-luminance orange
                  // and white on it measures 3.27.
                  foregroundColor: onAccent(context),
                  elevation: 2,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, size: 26),
                ),
              ),
      ),
      // No SafeArea: RootScreen's shared top bar already holds the inset, and
      // a second one here would push the list down again.
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final habits = store.visible;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (store.activeCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: _TodayCard(
                    done: store.doneTodayCount,
                    total: store.activeCount,
                  ),
                ),
              Expanded(
                child: !store.loaded
                    ? const SizedBox.shrink()
                    : habits.isEmpty
                    ? _EmptyState(store: store)
                    : store.compactLayout
                    ? CompactList(store: store, habits: habits)
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                        itemCount: habits.length,
                        onReorderItem: (from, to) =>
                            store.reorder(habits, from, to),
                        proxyDecorator: _lifted,
                        itemBuilder: (context, i) => Padding(
                          key: ValueKey(habits[i].id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: HabitTile(
                            habit: habits[i],
                            store: store,
                            index: i,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _lifted(Widget child, int index, Animation<double> animation) =>
    Material(
      color: Colors.transparent,
      child: Opacity(opacity: 0.92, child: child),
    );

/// Glow's hero card: the big number on the left, the week's dots on the right.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final complete = done == total;
    // Evening and everything done: Wick has earned the rest.
    final pose = complete
        ? (clock().hour >= 18 ? Wick.rest : Wick.celebrate)
        : done == 0
        ? Wick.standing
        : Wick.focus;

    return Semantics(
      container: true,
      label: complete
          ? 'All $total habits done today'
          : '$done of $total habits done today, ${total - done} to go',
      excludeSemantics: true,
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
        child: Row(
          children: [
            WickImage(pose, size: 42, semanticLabel: 'Wick the candle'),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$done',
                        style: text.headlineLarge?.copyWith(
                          fontSize: 22,
                          height: 1,
                        ),
                      ),
                      Text(' of $total', style: text.labelSmall),
                      const Spacer(),
                      Text(
                        complete ? 'All done' : '${total - done} to go',
                        style: text.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(pill),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 6,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(successOf(context)),
                    ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.store});

  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: WickMessage(
          pose: Wick.standing,
          size: 156,
          headline: 'Let\'s light your first habit',
          body:
              'Pick one small thing to do today. Wick will help you keep it going.',
          action: Column(
            children: [
              FilledButton(
                onPressed: () => showEditSheet(context, store),
                child: const Text('Add a habit'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => openStarterTemplates(context, store),
                child: const Text('Browse suggestions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashboard card. Icon, name, one line of description, a check control,
/// and underneath it every day this habit has existed as a lit or unlit cell.
///
/// The grid is the point: a streak number tells you where you are, a wall of
/// months tells you what you have actually been doing.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.store,
    required this.index,
  });

  final Habit habit;
  final HabitStore store;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Drag lives on a long press rather than a visible handle: the card is
    // already carrying five things, and a grip column beside the check
    // control was the sixth.
    return ReorderableDelayedDragStartListener(
      index: index,
      // One wrapper recolours the whole card — icon tile, grid, chips,
      // border and check control all read the accent rather than taking it
      // as a parameter each.
      child: HabitAccent(
        color: habitColorAt(habit.color),
        child: TintCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          onTap: () => openHabitDetail(context, store, habit),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  HabitIcon(habit: habit),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          habit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _subtitle(habit),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            // Without this a note is invisible from the one
                            // screen people actually live on — written once
                            // and then only findable by going looking for it.
                            if (habit.noteOn(today()).isNotEmpty)
                              _NoteMark(habit: habit, store: store),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  HabitMark(
                    habit: habit,
                    day: today(),
                    onTap: () => _check(context, store, habit),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Bare here: the month ruler, the weekday gutter and the streak
              // and schedule chips all live on the habit's own screen. The
              // dashboard is a wall of cards, and every one of them repeating
              // that furniture is what made it read as noise.
              ContributionGrid(habit: habit),
            ],
          ),
        ),
      ),
    );
  }

  void _check(BuildContext context, HabitStore store, Habit habit) =>
      _record(context, store, habit);
}

/// Records today, then decides whether the moment deserves recognition.
/// Order matters: finishing everything outranks a single habit's milestone,
/// and neither should fire twice in a day.
///
/// An ordinary check-off says nothing: a toast on every tap is noise you learn
/// to swipe past rather than read, and it covered the page you were using. The
/// milestones below still speak, and the day sheet is a long-press away for
/// anyone with something to write.
void _record(BuildContext context, HabitStore store, Habit habit) {
  final wasDone = habit.doneToday;
  store.bump(habit, today());

  // Only ever celebrate on the way up.
  if (wasDone || !habit.doneToday) return;

  final streak = habit.streak;

  if (store.doneTodayCount == store.activeCount &&
      store.claimMoment('all-done')) {
    showWickMoment(
      context,
      pose: Wick.celebrate,
      headline: 'All done today!',
      body: 'Every habit checked off. That\'s how the flame stays lit.',
      onNote: () => showDaySheet(context, store, habit, today()),
    );
    return;
  }

  if (streakMilestones.contains(streak) &&
      store.claimMoment('streak-$streak-${habit.id}')) {
    showWickMoment(
      context,
      pose: Wick.celebrate,
      headline: milestoneHeadline(streak, habit.isWeekly),
      body: '${habit.name} — kept going without a break.',
      onNote: () => showDaySheet(context, store, habit, today()),
    );
  }
}

String _subtitle(Habit h) {
  if (h.description.isNotEmpty) return h.description;
  if (h.isWeekly) {
    return '${h.doneDaysInWeek(today())} of ${h.perWeek} this week';
  }
  return h.isCountable ? '${h.target} a day' : 'Every day';
}

/// The habit's mark in a tinted tile — the reference's rounded square, not a
/// circle, so it rhymes with the grid cells underneath it.
///
/// A Lucide glyph in the habit's own colour, or the emoji it was created with
/// before icons existed. Emoji carry their own colour and are left alone.
class HabitIcon extends StatelessWidget {
  const HabitIcon({super.key, required this.habit, this.size = 44});

  final Habit habit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: chipFill(context),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: habit.icon.isEmpty
            ? Text(
                habit.emoji.isEmpty ? defaultEmoji : habit.emoji,
                style: TextStyle(fontSize: size * 0.48),
              )
            : Icon(
                iconFor(habit.icon),
                size: size * 0.5,
                color: accentOf(context),
              ),
      ),
    );
  }
}

/// The check-off control: a filled flame square when done, a hollow one when
/// not. A countable habit fills from the bottom as the day's amount climbs,
/// so partway there looks partway there.
class HabitMark extends StatelessWidget {
  const HabitMark({
    super.key,
    required this.habit,
    required this.day,
    this.onTap,
    this.size = 48,
  });

  final Habit habit;
  final DateTime day;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = habit.isDoneOn(day);
    final amount = habit.amountOn(day);
    final radius = BorderRadius.circular(size * 0.32);

    return Semantics(
      button: true,
      checked: done,
      label: habit.isCountable
          ? '${habit.name}, $amount of ${habit.target} today'
          : '${habit.name}, ${done ? "done" : "not done"} today',
      hint: habit.isCountable
          ? 'Add one'
          : done
          ? 'Mark as not done'
          : 'Mark as done',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: done ? accentOf(context) : Colors.transparent,
              borderRadius: radius,
              border: done
                  ? null
                  : Border.all(color: tint(context, 0.32), width: 1.6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The amount so far, rising from the bottom edge.
                if (!done && habit.isCountable && amount > 0)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: (amount / habit.target).clamp(0.0, 1.0),
                      child: Container(color: tint(context, 0.35)),
                    ),
                  ),
                if (habit.isCountable)
                  Text(
                    '$amount',
                    style: mono(
                      size * 0.33,
                      color: done ? onAccent(context) : scheme.onSurface,
                      weight: FontWeight.w700,
                    ),
                  )
                else
                  Icon(
                    Icons.check_rounded,
                    size: size * 0.5,
                    color: done ? onAccent(context) : tint(context, 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Says "there's something written about today", and opens it.
class _NoteMark extends StatelessWidget {
  const _NoteMark({required this.habit, required this.store});

  final Habit habit;
  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Note: ${habit.noteOn(today())}',
      hint: 'Edit',
      excludeSemantics: true,
      onTap: () => showDaySheet(context, store, habit, today()),
      child: InkWell(
        onTap: () => showDaySheet(context, store, habit, today()),
        borderRadius: BorderRadius.circular(pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Icon(
            Icons.sticky_note_2_outlined,
            size: 14,
            color: accentOf(context),
          ),
        ),
      ),
    );
  }
}
