import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'detail.dart';
import 'home.dart';
import 'notes_screen.dart';
import 'onboarding.dart';
import 'page_bar.dart';
import 'reminders.dart';
import 'store.dart';
import 'theme.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final store = HabitStore();
  final _navigator = GlobalKey<NavigatorState>();

  /// What the MaterialApp itself depends on. Everything else the store holds
  /// is read further down the tree, by widgets that listen for themselves.
  late var _shell = (store.themeMode, store.loaded, store.onboarded);

  @override
  void initState() {
    super.initState();
    store.addListener(_onStoreChanged);
    reminders.tappedHabitId.addListener(_openTappedHabit);
    _start();
  }

  /// The app used to rebuild `MaterialApp` — navigator, shell, every page — on
  /// every tap, because a check-off notifies the store like anything else. It
  /// only rebuilds now when something it actually renders changed.
  void _onStoreChanged() {
    final next = (store.themeMode, store.loaded, store.onboarded);
    if (next != _shell) setState(() => _shell = next);

    // Every change to a habit can change what should be sent — a check-off
    // suppresses today's nudge, an edit moves it. Rebuilding the whole
    // schedule is idempotent, so this needs no bookkeeping of its own.
    _syncReminders();
  }

  /// Prefs usually load in a frame or two, which would cut the launch
  /// animation off part-way — worse than not having one. The floor is the
  /// animation's own length, and loading runs inside it rather than after.
  static const _minimumSplash = Duration(milliseconds: 700);
  var _splashDone = false;

  Future<void> _start() async {
    final floor = Future<void>.delayed(_minimumSplash);
    await store.load();
    await reminders.init();
    await reminders.sync(store.habits); // once, up front, without the debounce
    await floor;
    if (mounted) setState(() => _splashDone = true);
    _openTappedHabit(); // a cold start from a tapped notification
  }

  void _syncReminders() => reminders.syncSoon(store.habits);

  void _openTappedHabit() {
    final id = reminders.tappedHabitId.value;
    if (id == null || !store.loaded) return;
    reminders.tappedHabitId.value = null;

    final habit =
        store.habits.where((h) => h.id == id).firstOrNull;
    final context = _navigator.currentContext;
    if (habit == null || context == null) return;
    _navigator.currentState?.popUntil((r) => r.isFirst);
    openHabitDetail(context, store, habit);
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    reminders.tappedHabitId.removeListener(_openTappedHabit);
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        navigatorKey: _navigator,
        title: 'Wick',
        debugShowCheckedModeBanner: false,
        theme: appTheme(dark: false),
        darkTheme: appTheme(dark: true),
        themeMode: store.themeMode,
        // Held until prefs are read, so onboarding never flashes for someone
        // who has already been through it. Painted rather than blank: this
        // frame has to be indistinguishable from the launch screen it takes
        // over from, or the app opens with a flicker.
        home: !store.loaded || !_splashDone
            ? const LaunchFrame()
            : store.onboarded
                ? RootScreen(store: store)
                : OnboardingScreen(store: store),
    );
  }
}

/// The launch screen, continued. Cream in both themes to match
/// `android/app/src/main/res/values/colors.xml` — the system splash paints
/// before Flutter starts and can't know the theme, so this frame takes the
/// handoff on the same ground and lets the app's own theme arrive with the
/// first real screen.
///
/// Shows the launcher icon, not a mascot pose: the system splash has already
/// put that mark on screen, and swapping to a different drawing of Wick
/// mid-launch reads as two apps starting.
///
/// The system splash icon is a static PNG; the motion lives here instead,
/// where it's a few lines rather than an AnimatedVectorDrawable.
class LaunchFrame extends StatefulWidget {
  const LaunchFrame({super.key});

  @override
  State<LaunchFrame> createState() => _LaunchFrameState();
}

class _LaunchFrameState extends State<LaunchFrame>
    with SingleTickerProviderStateMixin {
  late final _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);

    return Scaffold(
      backgroundColor: warmBg,
      body: Center(
        child: FadeTransition(
          opacity: rise,
          child: ScaleTransition(
            scale: Tween(begin: 0.86, end: 1.0).animate(rise),
            // 160 to sit where Android 12's splash icon sits (240 dp box,
            // inner 160 dp visible), so the mark doesn't jump on handoff.
            child: Image.asset(
              'assets/splash/wick_mark.png',
              height: 160,
              fit: BoxFit.fitHeight,
            ),
          ),
        ),
      ),
    );
  }
}

/// Analytics sits to the *right* of today, so a leftward swipe pulls it in and
/// a rightward swipe puts it away. The header icons do the same thing for
/// anyone who never discovers the gesture.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key, required this.store});

  final HabitStore store;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final _controller = PageController();

  /// The controller's fractional position, so the bar tracks the drag rather
  /// than snapping when a page settles — that continuous handoff is the whole
  /// point of a shared bar.
  ///
  /// A notifier rather than setState: only the two bars move with the drag,
  /// and rebuilding this State rebuilt the PageView too — a dashboard of
  /// contribution grids, the analytics maths and every note, on every frame
  /// of every swipe. That was the swipe lag.
  final _position = ValueNotifier(0.0);

  /// The landed page. The top bar's title only changes here, not with the
  /// drag, so it doesn't recount every note on every frame.
  final _page = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page;
      if (p == null) return;
      _position.value = p;
      _page.value = p.round();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _position.dispose();
    _page.dispose();
    super.dispose();
  }

  void _go(int page) => _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The title only changes when the *rounded* page does, so the bar
            // is rebuilt on a landing rather than on every frame — its notes
            // subtitle walks every habit's notes to count them.
            ValueListenableBuilder(
              valueListenable: _page,
              builder: (context, page, _) => ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) =>
                    PageBar(store: widget.store, page: page),
              ),
            ),
            Expanded(
              // The tab pill floats *over* the page rather than sitting in a
              // bar below it — so it goes in a Stack, not in
              // `bottomNavigationBar`, which would reserve a strip of the
              // scaffold for it. Every page already pads its scroll clear of
              // where it lands.
              child: Stack(
                children: [
                  PageView(
                    controller: _controller,
                    children: [
                      HomeScreen(store: widget.store),
                      AnalyticsScreen(store: widget.store),
                      NotesScreen(store: widget.store),
                    ],
                  ),
                  // PageTabs places itself and listens for itself, so a swipe
                  // repaints the pill rather than everything under a builder.
                  PageTabs(position: _position, onSelect: _go),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
