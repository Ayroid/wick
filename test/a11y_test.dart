import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/analytics_screen.dart';
import 'package:habit_tracker/detail.dart';
import 'package:habit_tracker/home.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything a screen reader would announce, in tree order. Asserting against
/// the compiled tree rather than the widget tree is the point — merged nodes
/// are what a person actually hears.
List<String> announcements(WidgetTester tester) {
  final out = <String>[];
  void walk(SemanticsNode n) {
    final data = n.getSemanticsData();
    if (data.label.isNotEmpty) {
      final tappable = data.hasAction(SemanticsAction.tap) ? '[tap] ' : '';
      out.add('$tappable${data.label.replaceAll('\n', ' · ')}');
    }
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  // ignore: deprecated_member_use — rootPipelineOwner has no semantics owner under the test binding.
  walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return out;
}

Matcher announces(Pattern p) => predicate<List<String>>(
      (all) => all.any((l) => p is RegExp ? p.hasMatch(l) : l.contains(p)),
      'announces "$p"',
    );

Matcher announcesTappable(Pattern p) => predicate<List<String>>(
      (all) => all.any((l) =>
          l.startsWith('[tap] ') &&
          (p is RegExp ? p.hasMatch(l) : l.contains(p))),
      'announces "$p" as something you can activate',
    );

Future<HabitStore> seeded() async {
  SharedPreferences.setMockInitialValues({});
  final store = HabitStore();
  await store.load();
  final read = store.add('Read', emoji: '📖');
  read.log[dayKey(shiftDays(today(), -1))] = 1;
  store.add('Water', emoji: '💧', target: 8);
  return store;
}

Widget wrap(Widget child) =>
    MaterialApp(theme: appTheme(dark: false), home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SemanticsHandle handle;
  setUp(() => handle = TestWidgetsFlutterBinding.instance.ensureSemantics());
  tearDown(() => handle.dispose());

  group('Today', () {
    testWidgets('every control is named and activatable', (tester) async {
      final store = await seeded();
      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pumpAndSettle();

      // The check-off control — the thing the whole app exists for.
      expect(announcements(tester), announcesTappable('Read, not done today'));
      expect(announcements(tester), announcesTappable('Water, 0 of 8 today'));

      store.bump(store.habits.first, today());
      await tester.pumpAndSettle();
      expect(announcements(tester), announcesTappable('Read, done today'));
    });

    testWidgets('the card grid summarises rather than reading every cell',
        (tester) async {
      final store = await seeded();
      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pumpAndSettle();

      final spoken = announcements(tester);
      // Six months of cells is unlistenable one day at a time, and none of
      // them are hittable on the card anyway — one count stands in for all.
      expect(spoken, announces(RegExp(r'\d+ days completed in the last \d+ days')));
      expect(spoken.where((l) => l.contains('days completed in the last')).length,
          store.visible.length);
      expect(spoken.where((l) => RegExp(r'\w+ \d+, \d{4}, ').hasMatch(l)),
          isEmpty);
    });

    testWidgets('the progress card is one sentence, not four fragments',
        (tester) async {
      final store = await seeded();
      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pumpAndSettle();
      expect(announcements(tester),
          announces('0 of 2 habits done today, 2 to go'));

      for (final h in store.habits) {
        store.toggle(h, today());
      }
      await tester.pumpAndSettle();
      expect(announcements(tester), announces('All 2 habits done today'));
    });

    testWidgets('meets the platform guidelines', (tester) async {
      final store = await seeded();
      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  group('Habit detail', () {
    testWidgets('heatmap cells carry their date and state', (tester) async {
      final store = await seeded();
      await tester.pumpWidget(
          wrap(HabitDetailScreen(store: store, habit: store.habits.first)));
      await tester.pumpAndSettle();

      expect(announcements(tester),
          announcesTappable(RegExp(r'\w+ \d+, \d{4}, (done|not done)')));
      // The streak and schedule chips live only here now, so this is the one
      // place that wording is asserted.
      expect(announcements(tester),
          announces(RegExp(r'Current streak: \d+ days')));
      expect(announcements(tester),
          announces(RegExp(r'Best streak: \d+ days')));
    });
  });

  group('Analytics', () {
    testWidgets('summarises the grid instead of reading 91 cells',
        (tester) async {
      final store = await seeded();
      await tester.pumpWidget(wrap(AnalyticsScreen(store: store)));
      await tester.pumpAndSettle();

      final spoken = announcements(tester);
      expect(spoken, announces(RegExp(r'Consistency over the last \d+ days')));
      expect(spoken, announces(RegExp(r'Mo: \d+ percent')));
      // The 91 individual cells stay silent — otherwise the card is unlistenable.
      expect(spoken.where((l) => l.contains('fully completed')).length, 1);
    });

    testWidgets('per-habit rows name the habit and its rate', (tester) async {
      final store = await seeded();
      await tester.pumpWidget(wrap(AnalyticsScreen(store: store)));
      await tester.pumpAndSettle();
      // The habit filter is a second, horizontal scrollable, so the vertical
      // one has to be named rather than inferred.
      await tester.scrollUntilVisible(
        find.text('By habit'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(announcements(tester),
          announces(RegExp(r'Read: \d+ percent over the last 30 days')));
    });
  });
}
