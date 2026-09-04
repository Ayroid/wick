import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/home.dart';
import 'package:habit_tracker/page_bar.dart';
import 'package:habit_tracker/store.dart';
import 'package:habit_tracker/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two things that float over the page have to agree with each other.
///
/// They are set in different files by different widgets, and a 56px default FAB
/// beside a 54px pill reads as a mistake at a glance — the kind nobody files a
/// bug about and everybody notices.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the add button is exactly as tall as the tab bar',
      (tester) async {
    final store = HabitStore();
    await store.load();
    store.add('Read');

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: HomeScreen(store: store),
    ));
    await tester.pumpAndSettle();

    final fab = tester.getSize(find.byType(FloatingActionButton));
    expect(fab.height, tabBarHeight);
    expect(fab.width, tabBarHeight, reason: 'and round, not an oval');
  });

  testWidgets('no add button until there is something to add beside',
      (tester) async {
    final store = HabitStore();
    await store.load();

    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: HomeScreen(store: store),
    ));
    await tester.pumpAndSettle();

    // The empty state carries its own call to action; a floating + on top of
    // it would be two buttons for one job.
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
