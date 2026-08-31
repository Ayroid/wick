import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/detail.dart';
import 'package:habit_tracker/grid.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the month calendar pages by swipe, and stops at this month',
      (tester) async {
    final store = HabitStore();
    await store.load();
    final habit = store.add('Read');

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: Scaffold(
        body: MonthCalendar(habit: habit, store: store),
      ),
    ));
    await tester.pumpAndSettle();

    String label() => (months[today().month - 1].substring(0, 3));
    expect(find.text('${label()} ${today().year}'), findsOneWidget);

    // Drag right: back a month.
    await tester.fling(find.byType(PageView), const Offset(600, 0), 1200);
    await tester.pumpAndSettle();
    final back = DateTime(today().year, today().month - 1);
    expect(
        find.text('${months[back.month - 1].substring(0, 3)} ${back.year}'),
        findsOneWidget);

    // And forward again, no further than this month.
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('${label()} ${today().year}'), findsOneWidget);
  });

  testWidgets('a scrollable grid draws its full year and opens on this week',
      (tester) async {
    final store = HabitStore();
    await store.load();
    final habit = store.add('Read');

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: Scaffold(
        body: Center(
          child: ContributionGrid(
            habit: habit,
            store: store,
            cell: 11,
            gap: 3.5,
            showMonths: true,
            showDays: true,
            maxWeeks: 53,
            scrollable: true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // A year of columns, not however many fit the screen.
    expect(find.byType(GridCell), findsNWidgets(53 * 7));

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.axis, Axis.horizontal);
    // Reversed, so the newest week is the one on screen at rest.
    expect(position.pixels, 0);
    expect(position.maxScrollExtent, greaterThan(0));

    // The weekday gutter is outside the scroll view: scrolling the columns
    // must not carry it off the left edge.
    final gutter = tester.getTopLeft(find.text('Tue'));
    await tester.drag(find.byType(Scrollable).first, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Tue')), gutter);
    expect(position.pixels, greaterThan(0));
  });
}
