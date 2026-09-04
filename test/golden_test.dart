import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/analytics_screen.dart';
import 'package:habit_tracker/day_sheet.dart';
import 'package:habit_tracker/detail.dart';
import 'package:habit_tracker/home.dart';
import 'package:habit_tracker/icons.dart';
import 'package:habit_tracker/notes_screen.dart';
import 'package:habit_tracker/main.dart';
import 'package:habit_tracker/onboarding.dart';
import 'package:habit_tracker/settings.dart';
import 'package:habit_tracker/share_card.dart';
import 'package:habit_tracker/clock.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/templates.dart';
import 'package:habit_tracker/theme.dart';
import 'package:habit_tracker/wick.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget tests ship with a placeholder font, so goldens need the real ones
/// loaded or every label, icon and emoji renders as a box.
Future<void> loadFonts() async {
  await (FontLoader('PlusJakartaSans')
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf')))
      .load();

  await _loadFile('MaterialIcons', _materialIconsPath());
  await _loadFile('Noto Color Emoji',
      '/usr/share/fonts/google-noto-color-emoji-fonts/Noto-COLRv1.ttf');
}

/// Walks up from the dart binary to the Flutter SDK root, wherever it's installed.
String _materialIconsPath() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.path != dir.parent.path) {
    final f = File('${dir.path}/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf');
    if (f.existsSync()) return f.path;
    dir = dir.parent;
  }
  return '';
}

/// Best effort: a missing system font only costs fidelity in the golden, so
/// don't fail the run over it.
Future<void> _loadFile(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  await (FontLoader(family)..addFont(Future.value(bytes.buffer.asByteData())))
      .load();
}

Future<HabitStore> seeded() async {
  SharedPreferences.setMockInitialValues({});
  final store = HabitStore();
  await store.load();

  // Sky, lime, violet and rose — spread across the palette, so a golden
  // catches a swatch that stops being wired through.
  final read = store.add('Read 20 pages', icon: 'book', color: 9);
  for (final d in [0, 1, 2, 3, 5, 6, 8, 9, 10]) {
    read.log[dayKey(shiftDays(today(), -d))] = 1;
  }

  final water = store.add('Drink water', icon: 'droplet', target: 8, color: 4);
  water.log[dayKey(today())] = 5;
  for (final d in [1, 2, 4, 5]) {
    water.log[dayKey(shiftDays(today(), -d))] = 8;
  }

  final gym = store.add('Gym', icon: 'dumbbell', perWeek: 3, color: 12);
  for (final d in [1, 3, 6, 8, 10, 13]) {
    gym.log[dayKey(shiftDays(today(), -d))] = 1;
  }

  // Emoji rather than an icon: habits created before icons existed
  // still render, and a golden should say so.
  store.add('Meditate', emoji: '🧘', icon: '', color: 16);
  return store;
}

/// Image.asset resolves asynchronously, which fake-async golden tests skip —
/// without precaching, every mascot renders as empty space.
Future<void> pumpScreen(WidgetTester tester, Widget widget) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(widget);
    await tester.idle();
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
}

Widget app(Widget home, {required bool dark}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(dark: dark),
      home: home,
    );


/// Mid-month, mid-morning, on a fixed weekday.
///
/// Every one of these screens renders a date or a greeting: the contribution
/// grid's month ruler, the weekday column it starts on, "Good morning". With
/// the real clock the images drift as the calendar moves and the whole suite
/// starts failing on its own, which is how a regression net stops being one.
final _pinned = DateTime(2026, 9, 17, 10, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadFonts);

  late DateTime Function() previousClock;
  setUp(() {
    previousClock = useFixedClock(_pinned);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(860, 1800)
      ..devicePixelRatio = 2.0;
  });
  tearDown(() => clock = previousClock);

  testWidgets('home — light', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(HomeScreen(store: store), dark: false));
    await expectLater(find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_light.png'));
  });

  testWidgets('home — dark', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(HomeScreen(store: store), dark: true));
    await expectLater(find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_dark.png'));
  });

  testWidgets('home — empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = HabitStore();
    await store.load();
    await pumpScreen(tester, app(HomeScreen(store: store), dark: false));
    await expectLater(find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_empty.png'));
  });


  testWidgets('new habit sheet — emoji defaults to the fire', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(HomeScreen(store: store), dark: false));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/edit_sheet.png'));
  });

  testWidgets('icon picker', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(HomeScreen(store: store), dark: false));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Icon'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/icon_picker.png'));
  });

  testWidgets('icon picker — emoji tab', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(HomeScreen(store: store), dark: false));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Icon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emoji'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/icon_picker_emoji.png'));
  });

  testWidgets('analytics — light', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(AnalyticsScreen(store: store), dark: false));
    await expectLater(find.byType(AnalyticsScreen),
        matchesGoldenFile('goldens/analytics_light.png'));
  });

  testWidgets('analytics — filtered to one habit', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(AnalyticsScreen(store: store), dark: true));
    // Scoped to a habit, the whole page takes that habit's colour — stat
    // tiles, trend line, consistency grid and all.
    // The chips are marks now, not names.
    await tester.tap(find.byIcon(iconFor('droplet')).first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(AnalyticsScreen),
        matchesGoldenFile('goldens/analytics_filtered.png'));
  });

  // The per-habit bars each take their habit's colour: they sit under a
  // HabitAccent, and reading the accent off the wrong context is what made
  // them all flame once before.
  testWidgets('analytics — by habit', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(AnalyticsScreen(store: store), dark: false));
    await tester.scrollUntilVisible(
      find.text('By habit'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(AnalyticsScreen),
        matchesGoldenFile('goldens/analytics_by_habit.png'));
  });

  testWidgets('analytics — dark', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(AnalyticsScreen(store: store), dark: true));
    await expectLater(find.byType(AnalyticsScreen),
        matchesGoldenFile('goldens/analytics_dark.png'));
  });

  testWidgets('celebration moment', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showWickMoment(
              context,
              pose: Wick.celebrate,
              headline: '7 days strong!',
              body: 'Read 20 pages — kept going without a break.',
            ),
            child: const Text('open'),
          ),
        ),
        dark: false,
      ));
      await tester.idle();
    });
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/celebration.png'));
  });

  testWidgets('habit detail', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(
      HabitDetailScreen(store: store, habit: store.habits.first),
      dark: false,
    ));
    await expectLater(find.byType(HabitDetailScreen),
        matchesGoldenFile('goldens/detail_light.png'));
  });

  testWidgets('habit detail — with notes', (tester) async {
    final store = await seeded();
    final h = store.habits.first;
    store.setNote(h, today(), 'Finished the chapter on sleep.');
    store.setNote(h, shiftDays(today(), -3), 'Only managed five pages.');
    await pumpScreen(tester, app(
      HabitDetailScreen(store: store, habit: h),
      dark: false,
    ));
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await expectLater(find.byType(HabitDetailScreen),
        matchesGoldenFile('goldens/detail_notes.png'));
  });

  testWidgets('home — done and undone habits, in the user\'s own order',
      (tester) async {
    final store = await seeded();
    // Two done, two not — and checking one off moves nothing.
    for (final h in store.habits.take(2)) {
      h.log[dayKey(today())] = h.target;
    }
    for (final h in store.habits.skip(2)) {
      h.log.remove(dayKey(today()));
    }
    await pumpScreen(tester, app(
        HomeScreen(store: store), dark: false));
    await expectLater(find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_done_mixed.png'));
  });

  testWidgets('day sheet — countable', (tester) async {
    final store = await seeded();
    final water = store.habits.firstWhere((h) => h.isCountable);
    store.setAmount(water, today(), 5);
    store.setNote(water, today(), 'Half by lunch.');
    await pumpScreen(tester, app(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDaySheet(context, store, water, today()),
            child: const Text('open'),
          ),
        ),
      ),
      dark: false,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/day_sheet.png'));
  });

  testWidgets('launch frame', (tester) async {
    await pumpScreen(tester, app(const LaunchFrame(), dark: false));
    await expectLater(
        find.byType(LaunchFrame), matchesGoldenFile('goldens/launch.png'));
  });

  testWidgets('notes screen', (tester) async {
    final store = await seeded();
    final read = store.habits.first;
    final water = store.habits.firstWhere((h) => h.isCountable);
    store.setNote(read, today(), 'Finished the chapter on sleep.');
    store.setNote(water, today(), 'Kept a glass on the desk — it helped.');
    store.setNote(read, shiftDays(today(), -1), 'Only managed five pages.');
    store.setNote(read, shiftDays(today(), -6), 'Read outside for once.');

    await pumpScreen(tester,
        app(NotesScreen(store: store), dark: false));
    await expectLater(
        find.byType(NotesScreen), matchesGoldenFile('goldens/notes.png'));
  });

  // The dashboard's other layout — same page, same habits, no grids.
  for (final dark in [false, true]) {
    testWidgets('compact layout — ${dark ? "dark" : "light"}', (tester) async {
      final store = await seeded();
      store.setCompactLayout(true);
      await pumpScreen(tester, app(HomeScreen(store: store), dark: dark));
      await expectLater(
          find.byType(HomeScreen),
          matchesGoldenFile(
              'goldens/compact_${dark ? "dark" : "light"}.png'));
    });
  }

  testWidgets('compact layout — a week wide, names hidden', (tester) async {
    final store = await seeded();
    store.setCompactLayout(true);
    store.setCompactDays(7);
    store.setCompactNames(false);
    await pumpScreen(tester, app(HomeScreen(store: store), dark: false));
    await expectLater(find.byType(HomeScreen),
        matchesGoldenFile('goldens/compact_week.png'));
  });

  testWidgets('compact list settings', (tester) async {
    final store = await seeded();
    store.setCompactLayout(true);
    await pumpScreen(tester, app(HomeScreen(store: store), dark: false));
    await tester.tap(find.text('Last 5 days'));
    await tester.pumpAndSettle();
    // The sheet is a route of its own, so the whole app is the frame here.
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/compact_settings.png'));
  });

  testWidgets('page bar — the layout switch, compact', (tester) async {
    final store = await seeded();
    store.setCompactLayout(true);
    await pumpScreen(tester, app(RootScreen(store: store), dark: false));
    await expectLater(find.byType(RootScreen),
        matchesGoldenFile('goldens/bar_compact.png'));
  });

  testWidgets('settings — a page, not a sheet', (tester) async {
    final store = await seeded();
    store.setArchived(store.habits.last, true);
    await pumpScreen(tester, app(SettingsScreen(store: store), dark: false));
    await expectLater(find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings.png'));
  });

  testWidgets('notes screen — empty', (tester) async {
    final store = await seeded();
    await pumpScreen(tester,
        app(NotesScreen(store: store), dark: false));
    await expectLater(find.byType(NotesScreen),
        matchesGoldenFile('goldens/notes_empty.png'));
  });

  testWidgets('home — a note on today shows on the tile', (tester) async {
    final store = await seeded();
    store.setNote(store.habits.first, today(), 'Felt unusually easy.');
    await pumpScreen(tester, app(
        HomeScreen(store: store), dark: false));
    await expectLater(find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_note_mark.png'));
  });

  // The shared bar is the only fixed chrome, so it needs seeing at each page
  // and mid-swipe, where the crossfade either works or looks like a glitch.
  for (final (index, name) in [(0, 'today'), (1, 'analytics'), (2, 'notes')]) {
    testWidgets('page bar — $name', (tester) async {
      final store = await seeded();
      store.setNote(store.habits.first, today(), 'Finished the chapter.');
      await pumpScreen(tester, app(RootScreen(store: store), dark: false));

      for (var i = 0; i < index; i++) {
        await tester.drag(find.byType(PageView), const Offset(-600, 0));
        await tester.pumpAndSettle();
      }
      await expectLater(find.byType(RootScreen),
          matchesGoldenFile('goldens/bar_$name.png'));
    });
  }

  testWidgets('page bar — mid-swipe', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(RootScreen(store: store), dark: false));

    // Halfway between Today and Analytics: the title has already switched,
    // and the bottom pill has faded out between the two tabs.
    final drag =
        await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await drag.moveBy(const Offset(-30, 0)); // past the touch slop
    await tester.pump();
    await drag.moveBy(const Offset(-185, 0));
    await tester.pump();

    await expectLater(find.byType(RootScreen),
        matchesGoldenFile('goldens/bar_midswipe.png'));
    await drag.up();
    await tester.pumpAndSettle();
  });

  testWidgets('share card', (tester) async {
    final store = await seeded();
    await pumpScreen(tester, app(
      Scaffold(
        backgroundColor: warmBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ShareCard(habit: store.habits.first),
          ),
        ),
      ),
      dark: false,
    ));
    await expectLater(
        find.byType(ShareCard), matchesGoldenFile('goldens/share_card.png'));
  });

  testWidgets('home — nothing done yet', (tester) async {
    final store = await seeded();
    for (final h in store.habits) {
      h.log.remove(dayKey(today()));
    }
    await pumpScreen(tester, app(
        HomeScreen(store: store), dark: false));
    await expectLater(find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_fresh.png'));
  });

  for (final (i, name) in [(0, 'flame'), (1, 'backfill'), (2, 'swipe')]) {
    testWidgets('onboarding page ${i + 1} — $name', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = HabitStore();
      await store.load();
      await pumpScreen(tester, app(OnboardingScreen(store: store), dark: false));
      for (var page = 0; page < i; page++) {
        await tester.drag(find.byType(PageView), const Offset(-420, 0));
        await tester.pumpAndSettle();
      }
      await expectLater(find.byType(OnboardingScreen),
          matchesGoldenFile('goldens/onboarding_${i + 1}_$name.png'));
    });
  }

  testWidgets('starter templates — first run', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = HabitStore();
    await store.load();
    await pumpScreen(tester, app(
      StarterTemplatesScreen(store: store, onDone: () {}, firstRun: true),
      dark: false,
    ));
    await expectLater(find.byType(StarterTemplatesScreen),
        matchesGoldenFile('goldens/templates_first_run.png'));
  });

  testWidgets('starter templates — with picks', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = HabitStore();
    await store.load();
    await pumpScreen(tester, app(
      StarterTemplatesScreen(store: store, onDone: () {}),
      dark: false,
    ));
    await tester.tap(find.text('Go for a walk'));
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(StarterTemplatesScreen),
        matchesGoldenFile('goldens/templates_picked.png'));
  });
}
