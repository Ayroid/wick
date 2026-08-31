import 'package:flutter/material.dart';

import 'store.dart';
import 'templates.dart';
import 'theme.dart';
import 'wick.dart';

/// Three pages, each teaching one thing the interface can't tell you by
/// itself: what the flame means, that past days are editable, and that
/// analytics is a swipe away.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store});

  final HabitStore store;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  var _page = 0;

  static const _pages = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages - 1) {
      openStarterTemplates(
        context,
        widget.store,
        firstRun: true,
        onDone: widget.store.completeOnboarding,
      );
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: last ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: last ? null : widget.store.completeOnboarding,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _Page(
                    pose: Wick.standing,
                    headline: 'This is Wick',
                    body: 'Every habit you keep up feeds the flame. '
                        'Miss a day and it burns lower — it never goes out.',
                    demo: _FlameLadder(),
                  ),
                  _Page(
                    pose: Wick.focus,
                    headline: 'Forgot to check one off?',
                    body: 'Each habit shows your last seven days. '
                        'Tap any day to fill it in — try it.',
                    demo: _WeekDemo(),
                  ),
                  _Page(
                    pose: Wick.celebrate,
                    headline: 'Swipe left for progress',
                    body: 'Streaks, heatmaps and the days you actually show '
                        'up are one swipe away — your notes are one more.',
                    demo: _SwipeHint(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? flameOf(context)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(pill),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _next,
                    child: Text(last ? 'Light your first habit' : 'Next'),
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

class _Page extends StatelessWidget {
  const _Page({
    required this.pose,
    required this.headline,
    required this.body,
    required this.demo,
  });

  final Wick pose;
  final String headline;
  final String body;
  final Widget demo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          WickImage(pose, size: 150, semanticLabel: 'Wick the candle'),
          const SizedBox(height: 28),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: text.headlineLarge?.copyWith(fontSize: 25),
          ),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center, style: text.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.secondary)),
          const SizedBox(height: 32),
          demo,
        ],
      ),
    );
  }
}

/// Page one: the flame at four strengths, so "it dims but never goes out"
/// is something you see rather than read.
class _FlameLadder extends StatelessWidget {
  const _FlameLadder();

  @override
  Widget build(BuildContext context) {
    const steps = [(0, 'missed'), (2, '2 days'), (9, '9 days'), (40, '40 days')];
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final (streak, label) in steps)
            Column(
              children: [
                SizedBox(
                  height: 42,
                  child: Center(child: FlameMark(streak: streak, size: 30)),
                ),
                const SizedBox(height: 6),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
        ],
      ),
    );
  }
}

/// Page two: a working week strip. Tapping it does what tapping the real one
/// does, which teaches the gesture better than an arrow pointing at it.
class _WeekDemo extends StatefulWidget {
  const _WeekDemo();

  @override
  State<_WeekDemo> createState() => _WeekDemoState();
}

class _WeekDemoState extends State<_WeekDemo> {
  // Thursday deliberately left blank — it's the one begging to be tapped.
  final _done = {0, 1, 2, 4, 5};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text('📖', style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text('Read 20 pages',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(
                  color: flameSoftOf(context),
                  borderRadius: BorderRadius.circular(pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlameMark(streak: _done.length, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${_done.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: flameOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final done = _done.contains(i);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(
                    () => done ? _done.remove(i) : _done.add(i)),
                child: Column(
                  children: [
                    Text(
                      weekdayShort[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: scheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: done
                            ? successOf(context)
                            : scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded,
                              size: 15, color: onSuccess)
                          : null,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Page three: two cards side by side with the gesture drawn between them.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MiniScreen(
          label: 'Today',
          color: successOf(context),
          filled: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              Icon(Icons.swipe_left_alt_outlined,
                  size: 26, color: flameOf(context)),
              const SizedBox(height: 2),
              Text('swipe',
                  style: TextStyle(fontSize: 10, color: scheme.secondary)),
            ],
          ),
        ),
        _MiniScreen(
          label: 'Analytics',
          color: progressOf(context),
          filled: false,
        ),
      ],
    );
  }
}

class _MiniScreen extends StatelessWidget {
  const _MiniScreen({
    required this.label,
    required this.color,
    required this.filled,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 96,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: cardShadow(isDark(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: filled || i.isEven
                              ? color
                              : color.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(pill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
