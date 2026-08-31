import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'store.dart';

/// The app's one reminder schedule. A global because there is exactly one
/// notification queue on the device — passing it through every widget that
/// might set a reminder would be ceremony around a singleton.
final reminders = Reminders();

/// Daily habit reminders.
///
/// There is no background isolate, so nothing runs on the device to decide
/// what to send. Instead the app schedules the next [_days] occurrences of
/// every reminder outright, and rebuilds that whole schedule whenever anything
/// that could change it changes — a launch, a check-off, an edit. Suppressing
/// today's reminder for a habit already done is then just: don't schedule it.
///
/// A week of lead time covers someone who doesn't open the app for a few days.
/// Past that, a missing notification is not their real problem.
class Reminders {
  Reminders({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// How far ahead the schedule is laid down.
  static const days = 7;
  static const _channel = 'habit_reminders';

  /// Set when a notification is tapped, so the app can open that habit. A
  /// notifier rather than a callback: the tap can arrive before there's a
  /// navigator to use, including on a cold start.
  final tappedHabitId = ValueNotifier<String?>(null);

  var _ready = false;

  /// Never throws: a phone that can't set up notifications still gets the
  /// rest of the app. [sync] is a no-op until this succeeds.
  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await _init();
    } catch (e) {
      debugPrint('reminders: unavailable ($e)');
    }
  }

  Future<void> _init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for later, alongside the Android prompt, so the request
          // lands when someone actually sets a reminder.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) =>
          tappedHabitId.value = r.payload,
    );

    // A tap that launched the app from cold never reaches the callback above.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      tappedHabitId.value = launch!.notificationResponse?.payload;
    }

    _ready = true;
  }

  /// Asks for whatever the platform needs. Returns false if the person said
  /// no, so the caller can say the reminder won't arrive rather than pretend.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  Timer? _pending;

  /// Coalesces a burst of changes into one rebuild. Every check-off notifies
  /// the store, and a rebuild is `cancelAll` plus up to 7 platform calls per
  /// habit — so checking off four habits in a row would otherwise fire five
  /// full reschedules across the method channel while the user is still
  /// tapping. Nothing is due within a second, so the delay costs nothing.
  void syncSoon(List<Habit> habits) {
    if (!_ready) return;
    _pending?.cancel();
    _pending = Timer(const Duration(seconds: 1), () => sync(habits));
  }

  /// Rebuilds the entire schedule from the current habits. Idempotent — which
  /// is what makes suppression work without tracking what was sent.
  Future<void> sync(List<Habit> habits) async {
    if (!_ready) return;
    _pending?.cancel();
    await _plugin.cancelAll();

    for (final due in dueReminders(habits, DateTime.now())) {
      final habit = due.habit;
      final day = due.day;
      final minutes = habit.reminder!;

      await _plugin.zonedSchedule(
        id: _idFor(habit, due.offset),
        // Every reminder is a one-shot at an absolute instant, so the IANA
        // zone name is never needed: Dart's DateTime constructor already
        // resolves local wall-clock time — DST included — and .from() just
        // converts that instant. This is what lets the app carry no timezone
        // lookup dependency.
        scheduledDate: tz.TZDateTime.from(
          DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60),
          tz.UTC,
        ),
        title: 'Still time for ${habit.name}',
        body: habit.isCountable
            ? '${habit.target - habit.amountOn(day)} to go today.'
            : 'A few minutes is enough to keep the streak.',
        payload: habit.id,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channel,
            'Habit reminders',
            channelDescription: 'A nudge for a habit you have not done yet.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Inexact on purpose: exact alarms need SCHEDULE_EXACT_ALARM, and a
        // habit nudge arriving at 8:10 instead of 8:00 costs nothing.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() {
    _pending?.cancel();
    return _ready ? _plugin.cancelAll() : Future.value();
  }

  /// Stable per habit and day. Ids are 32-bit, so the habit's id is folded
  /// down and given [_days] slots of room.
  static int _idFor(Habit habit, int offset) =>
      (habit.id.hashCode & 0x00FFFFFF) * days + offset;
}

typedef DueReminder = ({Habit habit, DateTime day, int offset});

/// Which nudges are still worth sending, as of [now]. Pure, so the rules that
/// actually matter — done means silent, a time already past today is skipped —
/// are testable without a notification plugin.
List<DueReminder> dueReminders(List<Habit> habits, DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  final out = <DueReminder>[];

  for (final habit in habits) {
    final minutes = habit.reminder;
    if (minutes == null || habit.archived) continue;

    for (var offset = 0; offset < Reminders.days; offset++) {
      final day = shiftDays(start, offset);
      // Already done — the whole point is not to nag about finished work.
      if (habit.isDoneOn(day)) continue;

      final at = DateTime(day.year, day.month, day.day, minutes ~/ 60,
          minutes % 60);
      if (!at.isAfter(now)) continue;

      out.add((habit: habit, day: day, offset: offset));
    }
  }
  return out;
}
