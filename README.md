# Wick

A habit tracker for Android. Build habits. One day at a time.

No account, no server, no analytics SDK: everything lives in
`SharedPreferences` on the phone, and a backup is a JSON file you export and
keep yourself.

## What it does

- **Dashboard** — a card per habit with a contribution grid, or a compact table
  with one row per habit and the last 1–7 days as cells. Same habits, two views;
  the switch is in the top bar.
- **Habits** — icon or emoji, colour, a daily target (`8 / Day`) or a weekly
  quota (`3 / Week`). Streaks count days for daily habits and weeks for weekly
  ones, and an unfinished today doesn't break one.
- **Notes** — a line about a day, written from a long-press on the day. Sparse:
  a day with nothing to say holds nothing.
- **Analytics** — completion rate, check-offs, best run, clean days, a trend and
  a consistency grid, filterable to one habit.
- **Reminders** — a per-habit daily notification, local, via
  `flutter_local_notifications`.
- **Backup** — export the whole log as JSON, restore it on another phone.

## Build

```sh
flutter pub get
flutter test          # widget + golden tests
flutter run
```

Release APKs:

```sh
tool/release.sh       # bump `version:` in pubspec.yaml first
```

That builds `--split-per-abi --release` and files the APKs under
`releases/<version>/`. Hand out the `arm64-v8a` one — every phone since ~2015.
Release signing comes from `android/key.properties` (untracked); without it the
build falls back to debug keys rather than failing.

## Layout

`lib/store.dart` is the model and the only thing that persists — habits, logs,
notes, prefs — as a `ChangeNotifier` everything else listens to.
`lib/theme.dart` holds the shared shapes (tinted cards, pills, the palette);
`lib/analytics.dart` is the maths, kept out of the screen that draws it. The
rest is one file per screen or sheet.

Goldens under `test/goldens/` are the real regression net for the UI — a change
that moves a pixel fails the run. Regenerate deliberately:

```sh
flutter test --update-goldens
```
