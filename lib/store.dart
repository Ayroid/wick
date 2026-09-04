import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clock.dart';
import 'icons.dart';
import 'theme.dart';

const _habitsKey = 'habits';
const _themeKey = 'themeMode';
const _momentsKey = 'moments';
const _onboardedKey = 'onboarded';
const _compactLayoutKey = 'compactLayout';
const _compactDaysKey = 'compactDays';
const _compactNamesKey = 'compactNames';

/// Calendar-day key, e.g. "2026-08-30". Habits are done on a *day*, not at an
/// instant, so days are stored as strings — no DateTime equality or timezone
/// drift to get wrong. Zero-padded, so lexical order is chronological order.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDay(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Day arithmetic via the constructor, never `add`/`subtract(Duration(days:))`:
/// a Duration is 24 real hours, which lands on the wrong calendar day across a
/// DST transition.
DateTime shiftDays(DateTime d, int by) => DateTime(d.year, d.month, d.day + by);

/// Monday of [d]'s week.
DateTime startOfWeek(DateTime d) => shiftDays(d, -(d.weekday - 1));

DateTime today() {
  final n = clock();
  return DateTime(n.year, n.month, n.day);
}

class Habit {
  Habit({
    required this.id,
    required this.name,
    this.description = '',
    this.emoji = '',
    this.icon = defaultIcon,
    this.color = defaultHabitColor,
    this.target = 1,
    this.perWeek = 7,
    this.archived = false,
    this.reminder,
    String? createdAt,
    Map<String, int>? log,
    Map<String, String>? notes,
  })  : createdAt = createdAt ?? dayKey(today()),
        log = log ?? <String, int>{},
        notes = notes ?? <String, String>{};

  final String id;

  /// The day this habit was created, as a day key. Recorded rather than
  /// inferred so analytics doesn't have to guess.
  final String createdAt;
  String name;

  /// One line under the name, in the person's own words — "Study 10 hours a
  /// day". Optional; blank means the card shows the schedule instead.
  String description;

  /// A key into `iconByKey`. Blank means this habit uses its [emoji] instead —
  /// the two are alternatives, and the picker's Icon/Emoji tabs are how you
  /// choose between them.
  String icon;

  /// Set only when [icon] is blank. Habits created before icons existed have
  /// one of these and no icon, and keep rendering exactly as they did.
  String emoji;

  /// Index into `habitColors`. Stored as an index rather than an ARGB value so
  /// the palette can be retuned — the light/dark pairs especially — without
  /// rewriting everyone's saved data.
  int color;

  /// Amount needed in a day to count it done. 1 = a plain check-off.
  int target;

  /// Days per week required. 7 = every day, and streaks count days; anything
  /// less means streaks count *weeks* that hit the quota.
  int perWeek;

  bool archived;

  /// Minutes past midnight for this habit's daily reminder, or null for none.
  /// Stored as a plain int so there's no time format to parse back.
  int? reminder;

  /// The reminder as wall-clock time, for the UI.
  TimeOfDay? get reminderAt => reminder == null
      ? null
      : TimeOfDay(hour: reminder! ~/ 60, minute: reminder! % 60);

  /// dayKey -> amount recorded that day.
  final Map<String, int> log;

  /// dayKey -> what happened that day, in the person's own words. Sparse: a
  /// day with no note holds no entry, and clearing a note removes the key.
  final Map<String, String> notes;

  String noteOn(DateTime d) => notes[dayKey(d)] ?? '';

  /// Days with a note, newest first.
  List<String> get notedDays =>
      notes.keys.toList()..sort((a, b) => b.compareTo(a));

  /// "3 / Week", "Daily", "8 / Day" — the schedule as the reference words it.
  String get scheduleLabel {
    if (isWeekly) return '$perWeek / Week';
    return isCountable ? '$target / Day' : 'Daily';
  }

  bool get isCountable => target > 1;
  bool get isWeekly => perWeek < 7;

  int amountOn(DateTime d) => log[dayKey(d)] ?? 0;
  bool isDoneOn(DateTime d) => amountOn(d) >= target;
  bool get doneToday => isDoneOn(today());

  int doneDaysInWeek(DateTime anyDayInWeek) {
    final monday = startOfWeek(anyDayInWeek);
    var n = 0;
    for (var i = 0; i < 7; i++) {
      if (isDoneOn(shiftDays(monday, i))) n++;
    }
    return n;
  }

  /// When this habit entered the picture — analytics needs it so a habit added
  /// yesterday isn't scored as having missed the last three months.
  ///
  /// Imported history can predate the record, so the earliest logged day wins
  /// if it's older than [createdAt].
  ///
  /// Cached: analytics asks for this once per habit *per day cell* — 91 times
  /// over on the consistency grid alone — and computing it scans every logged
  /// day. Keyed on [log].length rather than invalidated by hand: only adding
  /// or removing a day can move the start, and changing an existing day's
  /// amount cannot, so the length is an exact cache key and nothing outside
  /// this class has to remember to clear it.
  DateTime get startedOn {
    if (_startedOn == null || _startedOnFor != log.length) {
      _startedOnFor = log.length;
      _startedOn = _computeStartedOn();
    }
    return _startedOn!;
  }

  DateTime? _startedOn;
  int _startedOnFor = -1;

  DateTime _computeStartedOn() {
    final created = parseDay(createdAt);
    if (log.isEmpty) return created;
    final earliest =
        parseDay(log.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b));
    return earliest.isBefore(created) ? earliest : created;
  }

  Iterable<String> get _doneKeys =>
      log.entries.where((e) => e.value >= target).map((e) => e.key);

  int get totalDone => _doneKeys.length;

  /// For daily habits: consecutive days, ending today — or ending yesterday
  /// when today isn't done yet, since an unfinished today isn't a broken
  /// streak. For weekly habits: consecutive weeks that hit [perWeek], with the
  /// current week treated the same way.
  int get streak {
    if (isWeekly) {
      var w = startOfWeek(today());
      if (doneDaysInWeek(w) < perWeek) w = shiftDays(w, -7);
      var n = 0;
      while (doneDaysInWeek(w) >= perWeek) {
        n++;
        w = shiftDays(w, -7);
      }
      return n;
    }
    var d = today();
    if (!isDoneOn(d)) d = shiftDays(d, -1);
    var n = 0;
    while (isDoneOn(d)) {
      n++;
      d = shiftDays(d, -1);
    }
    return n;
  }

  /// Longest run ever, in the same unit [streak] uses.
  int get bestStreak {
    final done = _doneKeys.toSet();
    if (done.isEmpty) return 0;

    if (isWeekly) {
      var w = startOfWeek(parseDay(done.reduce((a, b) => a.compareTo(b) < 0 ? a : b)));
      final end = startOfWeek(today());
      var best = 0, run = 0;
      while (!w.isAfter(end)) {
        run = doneDaysInWeek(w) >= perWeek ? run + 1 : 0;
        if (run > best) best = run;
        w = shiftDays(w, 7);
      }
      return best;
    }

    var best = 0;
    for (final k in done) {
      // Only walk forward from the first day of each run.
      if (done.contains(dayKey(shiftDays(parseDay(k), -1)))) continue;
      var n = 0;
      var d = parseDay(k);
      while (done.contains(dayKey(d))) {
        n++;
        d = shiftDays(d, 1);
      }
      if (n > best) best = n;
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'emoji': emoji,
        'icon': icon,
        'color': color,
        'target': target,
        'perWeek': perWeek,
        'archived': archived,
        if (reminder != null) 'reminder': reminder,
        'createdAt': createdAt,
        'log': log,
        'notes': notes,
      };

  factory Habit.fromJson(Map<String, dynamic> j) {
    final log = <String, int>{};
    // v1 stored a plain list of done days; keep reading it so existing data
    // survives the upgrade.
    for (final d in (j['done'] as List? ?? const [])) {
      log[d as String] = 1;
    }
    (j['log'] as Map?)?.forEach((k, v) => log[k as String] = (v as num).toInt());

    final id = j['id'] as String;
    return Habit(
      id: id,
      name: j['name'] as String,
      description: j['description'] as String? ?? '',
      color: (j['color'] as num?)?.toInt() ?? defaultHabitColor,
      emoji: j['emoji'] as String? ?? '',
      // Data written before icons existed carries an emoji and no icon; it
      // must not silently acquire one, or every old habit repaints at once.
      icon: j['icon'] as String? ??
          ((j['emoji'] as String?)?.isNotEmpty ?? false ? '' : defaultIcon),
      target: (j['target'] as num?)?.toInt() ?? 1,
      perWeek: (j['perWeek'] as num?)?.toInt() ?? 7,
      archived: j['archived'] as bool? ?? false,
      reminder: (j['reminder'] as num?)?.toInt(),
      // Older records have no createdAt. Ids are microsecond timestamps, so
      // recover it from there; anything unparseable falls back to the earliest
      // logged day, then to today.
      createdAt: j['createdAt'] as String? ?? _recoverCreatedAt(id, log),
      log: log,
      notes: (j['notes'] as Map?)?.map((k, v) => MapEntry(k as String, '$v')),
    );
  }
}

String _recoverCreatedAt(String id, Map<String, int> log) {
  final micros = int.tryParse(id);
  if (micros != null && micros > 0) {
    final d = DateTime.fromMicrosecondsSinceEpoch(micros);
    if (d.year >= 2000 && d.year <= 2100) return dayKey(d);
  }
  if (log.isNotEmpty) {
    return log.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  }
  return dayKey(today());
}

class HabitStore extends ChangeNotifier {
  final List<Habit> habits = [];
  ThemeMode themeMode = ThemeMode.light;
  bool loaded = false;
  bool onboarded = false;

  /// Which layout the dashboard draws: cards with contribution grids, or the
  /// compact table. A view of the same habits either way — nothing about the
  /// data changes with it.
  bool compactLayout = false;

  /// How many days the compact list shows, ending today. 1–7: past a week a
  /// row stops being scannable at a glance, which is the only thing that view
  /// is for — the contribution grid already covers the long view.
  int compactDays = 5;

  /// Whether the compact list writes habit names beside their icons. Off is
  /// for people with more habits than fit a line.
  bool compactNames = true;

  // Celebrations already shown today, so toggling a habit off and on — or just
  // reopening the app — doesn't replay the same moment.
  final Set<String> _moments = {};
  String _momentsDay = '';

  /// Every unarchived habit, in the user's own order — checking one off does
  /// not move it.
  List<Habit> get visible => habits.where((h) => !h.archived).toList();

  List<Habit> get archived => habits.where((h) => h.archived).toList();

  int get doneTodayCount => habits.where((h) => !h.archived && h.doneToday).length;
  int get activeCount => habits.where((h) => !h.archived).length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[prefs.getInt(_themeKey) ?? ThemeMode.light.index];
    onboarded = prefs.getBool(_onboardedKey) ?? false;
    // Clamped, not trusted: a hand-edited or future-written pref must not be
    // able to ask for zero columns.
    compactLayout = prefs.getBool(_compactLayoutKey) ?? compactLayout;
    compactDays = (prefs.getInt(_compactDaysKey) ?? compactDays).clamp(1, 7);
    compactNames = prefs.getBool(_compactNamesKey) ?? compactNames;
    _readMoments(prefs.getString(_momentsKey));
    final raw = prefs.getString(_habitsKey);
    if (raw != null) {
      try {
        habits.addAll(_decode(raw));
      } catch (e) {
        // Corrupt blob: start empty rather than bricking launch.
        debugPrint('habits: could not read stored data ($e)');
      }
    }
    loaded = true;
    notifyListeners();
  }

  Habit add(String name,
      {String description = '',
      String emoji = '',
      String icon = defaultIcon,
      int color = defaultHabitColor,
      int target = 1,
      int perWeek = 7,
      int? reminder}) {
    final h = Habit(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      description: description,
      emoji: emoji,
      icon: icon,
      color: color,
      target: target,
      perWeek: perWeek,
      reminder: reminder,
    );
    habits.add(h);
    _commit();
    return h;
  }

  /// [clearReminder] because null means "leave it alone" for every other
  /// field here, and turning a reminder off has to be expressible.
  void edit(Habit h,
      {String? name,
      String? description,
      String? emoji,
      String? icon,
      int? color,
      int? target,
      int? perWeek,
      int? reminder,
      bool clearReminder = false}) {
    h.name = name ?? h.name;
    h.description = description ?? h.description;
    h.emoji = emoji ?? h.emoji;
    h.icon = icon ?? h.icon;
    h.color = color ?? h.color;
    h.target = target ?? h.target;
    h.perWeek = perWeek ?? h.perWeek;
    h.reminder = clearReminder ? null : (reminder ?? h.reminder);
    _commit();
  }

  /// Returns the removed habit's index so a delete can be undone.
  int remove(Habit h) {
    final i = habits.indexOf(h);
    habits.remove(h);
    _commit();
    return i;
  }

  void insertAt(int index, Habit h) {
    habits.insert(index.clamp(0, habits.length), h);
    _commit();
  }

  void setArchived(Habit h, bool value) {
    h.archived = value;
    _commit();
  }

  /// [minutes] past midnight, or null to turn the reminder off.
  void setReminder(Habit h, int? minutes) {
    h.reminder = minutes;
    _commit();
  }

  /// One tap on the habit's own control: +1, wrapping to 0 past [Habit.target].
  /// For a plain check-off (target 1) that is exactly a toggle.
  void bump(Habit h, DateTime day) {
    final next = h.amountOn(day) + 1;
    _set(h, day, next > h.target ? 0 : next);
  }

  /// Backfill from a week dot or heatmap cell: straight done/not-done.
  void toggle(Habit h, DateTime day) =>
      _set(h, day, h.isDoneOn(day) ? 0 : h.target);

  /// Blank (or whitespace-only) clears the day's note rather than storing an
  /// empty string, so [Habit.notedDays] only ever lists days worth showing.
  void setNote(Habit h, DateTime day, String text) {
    final t = text.trim();
    t.isEmpty ? h.notes.remove(dayKey(day)) : h.notes[dayKey(day)] = t;
    _commit();
  }

  /// An exact amount for a day, clamped to the habit's target. Backfilling a
  /// countable habit needs this — tapping a dot can only mean "all of it".
  void setAmount(Habit h, DateTime day, int amount) =>
      _set(h, day, amount.clamp(0, h.target));

  void _set(Habit h, DateTime day, int amount) {
    amount <= 0 ? h.log.remove(dayKey(day)) : h.log[dayKey(day)] = amount;
    _commit();
  }

  /// Repositions [moved] relative to the list the user actually sees, so drag
  /// order survives filtering and the unfinished-first sort.
  /// [newIndex] is already adjusted for the removal of the dragged item, as
  /// ReorderableListView's onReorderItem provides it.
  void reorder(List<Habit> view, int oldIndex, int newIndex) {
    if (newIndex == oldIndex) return;
    final moved = view[oldIndex];
    final rest = [...view]..removeAt(oldIndex);
    habits.remove(moved);
    habits.insert(
      newIndex >= rest.length ? habits.length : habits.indexOf(rest[newIndex]),
      moved,
    );
    _commit();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_themeKey, mode.index));
  }

  void setCompactLayout(bool compact) {
    if (compactLayout == compact) return;
    compactLayout = compact;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_compactLayoutKey, compact));
  }

  void setCompactDays(int days) {
    compactDays = days.clamp(1, 7);
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_compactDaysKey, compactDays));
  }

  void setCompactNames(bool show) {
    compactNames = show;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_compactNamesKey, show));
  }

  void completeOnboarding() {
    if (onboarded) return;
    onboarded = true;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setBool(_onboardedKey, true));
  }

  /// True the first time [key] is claimed today; false every time after.
  bool claimMoment(String key) {
    final d = dayKey(today());
    if (_momentsDay != d) {
      _momentsDay = d;
      _moments.clear();
    }
    if (!_moments.add(key)) return false;
    SharedPreferences.getInstance().then((p) => p.setString(
        _momentsKey, jsonEncode({'day': _momentsDay, 'shown': _moments.toList()})));
    return true;
  }

  void _readMoments(String? raw) {
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['day'] != dayKey(today())) return; // yesterday's moments don't carry
      _momentsDay = m['day'] as String;
      _moments.addAll((m['shown'] as List).cast<String>());
    } catch (_) {
      // Not worth failing a launch over a celebration record.
    }
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'habits': habits.map((h) => h.toJson()).toList(),
      });

  /// Replaces everything. Throws on malformed input so the caller can report it
  /// without having already destroyed the existing data.
  void importJson(String raw) {
    final replacement = _decode(raw);
    habits
      ..clear()
      ..addAll(replacement);
    _commit();
  }

  /// Accepts both the bare habit list written by v1 and the wrapped export.
  List<Habit> _decode(String raw) {
    final data = jsonDecode(raw);
    final list = data is Map ? data['habits'] as List : data as List;
    return list
        .map((e) => Habit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _commit() {
    notifyListeners();
    // Fire-and-forget: the UI never waits on disk.
    SharedPreferences.getInstance().then((p) => p.setString(
        _habitsKey, jsonEncode(habits.map((h) => h.toJson()).toList())));
  }
}
