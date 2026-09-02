import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/detail.dart';
import 'package:habit_tracker/theme.dart';

void main() {
  Widget host(void Function(BuildContext) onPress) => MaterialApp(
        theme: appTheme(dark: false),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onPress(context),
              child: const Text('go'),
            ),
          ),
        ),
      );

  testWidgets('a toast goes away on its own', (tester) async {
    await tester.pumpWidget(host((c) => toast(c, 'Archived')));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Archived'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsNothing);
  });

  testWidgets('and still goes away with accessible navigation on',
      (tester) async {
    // One of the ways a phone silently disables ScaffoldMessenger's own
    // auto-dismiss, and why showToast keeps a timer of its own regardless.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(host((c) => toast(c, 'Archived')));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Archived'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsNothing);
  });

  testWidgets('a later toast is not cut short by the one it replaced',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(dark: false),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => toast(context, 'First'),
                child: const Text('first'),
              ),
              TextButton(
                onPressed: () => toast(context, 'Second'),
                child: const Text('second'),
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.text('first'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // two seconds left on it

    await tester.tap(find.text('second'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700)); // out, then in
    expect(find.text('Second'), findsOneWidget);

    // t = 3s: where the first toast's own timer fires. It must be cancelled by
    // then, or it takes the toast that replaced it down with it.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Second'), findsOneWidget);

    // Let the second one's own timer run out — a live timer at the end of a
    // test fails it, which is the point: the timer is real and it does fire.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsNothing);
  });
}
