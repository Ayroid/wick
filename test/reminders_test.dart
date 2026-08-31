import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/reminders.dart';
import 'package:habit_tracker/store.dart';

Habit habitWith({int? reminder, int target = 1, bool archived = false}) => Habit(
      id: '1',
      name: 'Read',
      target: target,
      archived: archived,
      reminder: reminder,
    );

void main() {
  final noon = DateTime(2026, 8, 31, 12);
  const eightPm = 20 * 60;
  const eightAm = 8 * 60;

  test('no reminder set means nothing is scheduled', () {
    expect(dueReminders([habitWith()], noon), isEmpty);
  });

  test('schedules a week ahead from a time still to come today', () {
    final due = dueReminders([habitWith(reminder: eightPm)], noon);
    expect(due.length, Reminders.days);
    expect(due.first.day, DateTime(2026, 8, 31));
    expect(due.last.day, DateTime(2026, 9, 6));
  });

  test('a time already past today starts from tomorrow', () {
    final due = dueReminders([habitWith(reminder: eightAm)], noon);
    expect(due.length, Reminders.days - 1);
    expect(due.first.day, DateTime(2026, 9, 1));
  });

  test('a habit already done today is silent today but not tomorrow', () {
    final h = habitWith(reminder: eightPm);
    h.log[dayKey(DateTime(2026, 8, 31))] = 1;

    final due = dueReminders([h], noon);
    expect(due.map((d) => d.day), isNot(contains(DateTime(2026, 8, 31))));
    expect(due.map((d) => d.day), contains(DateTime(2026, 9, 1)));
  });

  test('a countable habit is silent only once the target is met', () {
    final h = habitWith(reminder: eightPm, target: 8);
    h.log[dayKey(DateTime(2026, 8, 31))] = 5; // part way

    expect(dueReminders([h], noon).first.day, DateTime(2026, 8, 31));

    h.log[dayKey(DateTime(2026, 8, 31))] = 8;
    expect(dueReminders([h], noon).first.day, DateTime(2026, 9, 1));
  });

  test('an archived habit never nudges', () {
    expect(
      dueReminders([habitWith(reminder: eightPm, archived: true)], noon),
      isEmpty,
    );
  });

  test('every scheduled day gets its own id slot', () {
    final due = dueReminders([habitWith(reminder: eightPm)], noon);
    expect(due.map((d) => d.offset).toSet().length, due.length);
  });
}
