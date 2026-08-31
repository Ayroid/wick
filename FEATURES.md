# Wick — feature checklist

Working checklist for what's built, what's broken, and what's next. Tick a box
when it ships. Keep entries one line; the reasoning lives in the code comments.

**Status:** 20 source files · 7,419 lines · 181 tests · 29 goldens · 6 runtime deps
**Verified on:** Android device — runs, emoji render, data survives a cold kill
**Last release:** 1.0.0 — arm64 17.9 MB, release-signed (`5D:77:3C:62…75BD99`)
**Current build:** arm64 **18.6 MB** — +0.7 MB for Lucide (see below)

**On build size:** ship `--split-per-abi` or the `.aab`, never the plain APK.
A fat `app-release.apk` carries all three ABIs — three copies of
`libflutter.so` and `libapp.so`, of which a phone uses one. Per-device it's
**17.9 MB** (arm64), of which 11.6 MB is the Flutter engine — the floor for any
Flutter app. The `.aab` also reads large on disk; Play splits it.

What the size pass actually bought, arm64 20.2 → 17.9 MB:
| Change | Saved |
|---|---|
| Mascots cut from ~1250 px to 512 px, palette-quantised | 1.35 MB |
| `--obfuscate --split-debug-info` (`libapp.so` 5.3 → 4.7 MB) | 0.6 MB |
| Dropped unused `cupertino_icons` | 0.25 MB |

Lucide costs **+0.7 MB** over the 1.0.0 baseline. `--tree-shake-icons` (on by
default in release) cuts `lucide.ttf` from 859 KB to **95 KB**, and the six
variable-weight faces the package also declares drop out entirely because
nothing names them. The rest is the package's 28,420 generated `IconData`
constants landing in `libapp.so`. There is a `ponytail:` note in
`lib/icons.dart` with the upgrade path if that ever matters — the keys are the
interface, so dropping the dependency would change nothing outside that file.

R8 (`isMinifyEnabled`) was measured and **rejected**: it grew `classes.dex` by
8 KB and left the APK byte-identical, because the dex is Flutter embedding and
plugin code that is all reachable. Not worth the reflection risk for nothing.

---

## Design decisions — settled, don't re-litigate

- **Storage** is one JSON blob in `shared_preferences`. Revisit only when
  measurement says so, around two years of daily data. Not before.
- **Days are strings** (`"2026-08-30"`), not `DateTime`. Sidesteps equality and
  timezones; lexical order is chronological.
- **Date maths goes through the `DateTime` constructor**, never
  `subtract(Duration(days:))` — a Duration is 24 real hours and lands on the
  wrong calendar day across DST.
- **State is one `ChangeNotifier`.** No state-management package.
- **Colour is semantic:** a habit's own swatch fills anything measuring *that
  habit* — its grid, check control, chips, card. Yellow `#FDC000` still fills
  anything measuring *across* habits: the progress card, and analytics while
  it is unfiltered. Orange `#FD5500` is the brand accent — chrome, primary
  actions, the flame. Navy `#102A5C` for all text.
- **Each habit has its own colour, and it drives everything about that
  habit.** Card tint, border, icon tile, chips, check control and grid cells,
  the way the reference does it — a colour that only tinted the border would
  be invisible next to a grid that never changed. Twenty-one swatches; Orange
  is the default, so a habit nobody touches still looks like Wick.
- **Chrome is never the habit's colour.** The FAB, Save, the nav bar, the
  progress card, settings, onboarding and the unfiltered analytics page stay
  brand flame. The accent means "this specific habit"; where there is no one
  habit being spoken about, there is no accent.
- **The accent travels by `HabitAccent`, not by parameter.** An
  `InheritedWidget` that every tint helper reads, so a card wraps itself once
  and its icon, grid, chips, border and check control all follow. The
  alternative was threading a `Color` through six widgets and forgetting it in
  one of them.
- **One value per swatch, identical in both themes.** Darkening the palette
  for light mode was built, looked at, and thrown away — the partners came out
  as mud. The colours are the colours.
- **The grid keeps a dark well in both themes**, which is what makes that
  possible. Every swatch is a *light* colour, so on cream a lit cell and an
  unlit one are both light and no alpha gets them 3:1 apart — the worst pair
  measures 1.26 and no amount of tuning moves it. Inside a dark well the gap
  is 3.98. The reference gives its grid a well too; ours is simply dark on a
  cream page as well as on a black one.
- **On cream the accent fills, it never writes.** A chip at night is the
  reference's — a faint well of the accent with the accent as ink, 5.02:1 on
  black. The same chip on cream is invisible, so there the accent becomes the
  fill and the ink flips to whatever contrasts with it. Same rule the brand
  already set for yellow.
- **The palette is contrast-tested, per swatch, in both themes.** Lit-vs-unlit
  cell inside the well, grid labels on the well, chip text on its own ground,
  and glyph on a full-strength fill — against the surfaces they actually
  resolve to. `test/palette_test.dart` fails if a swatch is added or retuned
  below the line.
- **`onAccent` measures, it does not threshold.** Whether a check mark is navy
  or white is decided by comparing both contrasts. A lightness cutoff got 14 of
  21 swatches wrong — a mid-luminance red reads as "dark" to a threshold and
  gets white, when navy is clearer by a full point.
- **The accent cannot carry small text on cream.** The palette's light values
  top out near 3.9:1 against the 12% wells they sit in, short of the 4.5 a
  12 px label needs. So `onTint` is the accent at night and the normal
  foreground by day — the same rule the brand already sets for yellow. Fill and
  glyph carry the colour; weight carries the text.
- **Icons are Lucide, from `lucide_icons_flutter`.** A font, not a pile of
  SVGs: an icon costs a codepoint rather than an asset, and tree-shaking
  strips every glyph the catalogue does not name. ~250 icons in the
  reference's six categories.
- **Icons are stored by key, never by codepoint.** The font is a dependency
  and its codepoints are its business; a package upgrade that renumbers them
  must not silently repaint everyone's habits. An unknown key falls back to
  the default rather than throwing — a stored icon can outlive a rename.
- **Icon and emoji are alternatives, not a merged set.** The picker's
  Icon/Emoji tabs are the reference's own control. A habit has one or the
  other: a blank `icon` means "use the emoji", which is exactly what every
  habit created before icons existed looks like, so none of them repaint.
  Emoji carry their own colour and are never tinted.
- **Lucide does not have every icon the reference draws** — no tennis ball,
  golf flag, hockey stick or boxing glove. Those take the nearest thing that
  exists; the Emoji tab covers whatever is still missing.
- **The swatch is stored as an index, not an ARGB value**, so the palette can
  be retuned — the light/dark pairs especially — without rewriting saved data.
  Out-of-range clamps rather than throwing: an export is a hand-editable file.
- **Cards are tint + hairline, never elevation.** `TintCard` blends the flame
  over the *page* ground, not over `surface` — starting a step lighter and then
  tinting would undo the effect. No shadow. `SoftCard` (shadowed, untinted)
  survives for the progress card, settings and analytics.
- **Small labels are monospace.** Month names, weekday initials, streak counts,
  dates, "Aug 2026". It is what makes a wall of digits read as data rather than
  prose. The family is the platform's own — nothing bundled, no new asset.
- **The dashboard grid is not tappable.** Six months of 9 px cells cannot be
  hit and cannot be listened to; the card opens the detail screen, the check
  control records today, and per-day editing lives on the detail grid and month
  calendar where the cells are big enough. The card's grid announces one
  summary per habit instead of ~190 cells.
- **Reordering moved to a long press.** The card already carries an icon, a
  name, a description, a check control, a grid and two chips; a visible grip
  column was the seventh thing. `ReorderableDelayedDragStartListener`.
- **The month calendar is always six rows.** Five would make the card change
  height as you page through the year. Six covers every month — a 31-day month
  starting on a Sunday is the worst case and ends in row 5. Asserted across a
  decade in `test/calendar_test.dart`.
- **The grid sizes itself from its width**, rather than a fixed week count, so
  the same widget fills a full-width card and a narrow tile without clipping or
  leaving a gutter. `maxWeeks` caps it so a tablet doesn't draw three years of
  empty cells for a habit added last week.
- **`GridFrame` owns the grid layout; callers own the cells.** Analytics scores
  a day across every habit, a habit card scores only itself, and the week
  arithmetic, month ruler and day gutter are the same either way. Analytics used
  to keep a second copy of all of it.
- **The trend chart is a `CustomPainter`.** Forty lines against a charting
  dependency an order of magnitude bigger. The area is the line's own path
  closed to the baseline, so fill and stroke cannot disagree about where the
  data is. Only the newest week gets a dot — one per point turns a twelve-week
  line into beads.
- **The running week is scored on days lived, not days remaining.** Counting
  the rest of the week as misses made the last point of the trend collapse
  every Monday morning.
- **A week before any habit existed is absent from the trend, not zero.** A
  flat run of nothing on the left of a chart reads as failure rather than as
  "you weren't here yet". Same rule the consistency grid already used.
- **Analytics scopes to one habit.** Averaged across nine habits the page
  answers "how am I doing" and nothing else; the filter row makes it answer
  "how is *this* going". The filter is held by **id**, not by object — an
  import replaces every habit, and a filter pointing at a freed one would
  silently show an empty page.
- **Yellow never carries text.** Glyphs on a yellow fill are navy (white fails
  contrast), and yellow text on cream is unreadable — accented numbers take the
  normal foreground and let weight do the work.
- **Dark is neutral black**, not navy — a navy ground reads as "unlit blue"
  rather than dark. Flame stays the only colour at night.
- **Light is the default** when no choice is stored, not System.
- **Wick is never disappointed.** A missed day dims the flame; it never goes
  out. There is no sad pose and there will not be one.
- **Frequencies default to realistic**, not aspirational — gym is 3×/week.
- **The settle animation lives in `HomeScreen`, not the tile.** The list
  rebuilds children by index, so a habit that changes position is a *new*
  tile — one with no idea it had just travelled. `ReorderableListView.builder`
  has no `findChildIndexCallback` to fix that, so the screen tracks which id
  just landed and tells the tile.
- **The shell is one top bar and one bottom bar**, both fixed; pages only ever
  move their own content. Navigation is the bottom bar and the swipe — no back
  buttons.
- **The top title does not animate.** Two headlines sliding over each other is
  motion for its own sake, and the page underneath already shows it moved. The
  bottom pill *does* track the drag, but fades out between tabs — the icons
  don't move, so a pill left at full strength mid-swipe reads as a stray blob.
- **`Habit.startedOn` is cached against `log.length`.** Analytics asks for it
  once per habit *per day cell* — 91 times over on the consistency grid alone —
  and computing it scans every logged day. Only adding or removing a day can
  move the start, so the length is an exact key and no caller has to remember
  to clear it.
- **Reminder rescheduling is debounced 1 s.** A rebuild is `cancelAll` plus up
  to 7 platform calls per habit, and every check-off notifies the store —
  four taps in a row used to fire five full reschedules across the channel.
- **`MaterialApp` rebuilds only when the shell changes.** It used to sit inside
  a `ListenableBuilder` on the store, so every tap rebuilt the navigator and
  all three pages; it now compares `(themeMode, loaded, onboarded)` and the
  pages listen for themselves.
- **Notes are offered, never asked for.** The offer rides on the toast that
  was already appearing after a check-off (and on the celebration dialog that
  replaces it, since a milestone is exactly when there's something to say).
  One plain-text note per habit per day. No rich text, mood, photos, tags,
  attachments, prompts, or analysis — Wick is not journaling software.
- **Tap fills, hold sets.** A tap on a dot or cell can only mean "all of it";
  8 taps on a 22 px dot to backfill Tuesday's water is not a real interaction.
  The exact figure lives in the day sheet behind a long press.
- **Reminders have no background isolate.** Nothing runs on the device to
  decide what to send, so the app lays down the next 7 days of one-shots for
  every habit and rebuilds that whole schedule on any change. Suppression is
  then just "don't schedule it". No rule engine, no repeating alarms to cancel.
- **The launch screen shows the launcher icon, not a mascot pose.** The system
  splash has already put that mark on screen; swapping to a different drawing
  of Wick mid-launch reads as two apps starting.
  `assets/splash/wick_mark.png` is the icon trimmed and cut to 512 px — 9 KB
  palette-quantised, against 544 KB for the source art.
- **The splash is cream in both themes**, with no `values-night` override. It
  paints before Flutter starts, so it cannot read the in-app theme choice; a
  dark variant only means the app opens on a black rectangle for anyone whose
  phone is in dark mode. `NormalTheme` — the window *behind* the running app —
  does follow the system.
- **No timezone-lookup dependency.** `flutter_timezone` applies the Kotlin
  Gradle Plugin, which future Flutter versions will refuse to build. It isn't
  needed: every reminder is a one-shot at an absolute instant, and Dart's
  `DateTime` constructor already resolves local wall-clock time with DST, so
  `TZDateTime.from(local, tz.UTC)` is the whole conversion. An IANA zone name
  would only be needed for *repeating* schedules.
- **Reminders are scheduled inexactly.** `exactAllowWhileIdle` needs
  `SCHEDULE_EXACT_ALARM` and a Play policy declaration; a nudge landing at 8:10
  instead of 8:00 is not worth either.
- **`Tooltip` needs `triggerMode: manual`** wherever a long press does
  something — it claims long-press by default and silently wins it.
- **`WickImage` decodes at display size** (`cacheHeight`). The art is ~1250 px
  and the largest use is 156 — decoding full-size cost megabytes of image cache
  per pose and made the golden downsample drift between runs.

---

## Shipped

### Foundations
- [x] Local-only storage, one JSON blob, fire-and-forget saves
- [x] `HabitStore` / `ListenableBuilder`, no state package
- [x] String day keys + DST-proof arithmetic
- [x] v1 data migration (bare `done: [...]` list)
- [x] Corrupt-blob tolerance — starts empty, doesn't crash
- [x] Once-a-day celebration guard (`claimMoment`, persisted)
- [x] Four platform targets (android, ios, linux, web)

### Brand & mascot
- [x] Wick palette + light/dark themes
- [x] Plus Jakarta Sans bundled (variable, offline)
- [x] Six mascot poses with fallback when artwork is missing
- [x] `FlameMark` — drawn, scales with streak, sparkles past 30 days
- [x] Launcher icons, both platforms, `#FFF8F3` adaptive background
- [x] App named "Wick" across every target
- [x] Branded launch screen — cream ground and the launcher icon, the same
      mark in the system splash and in the app's own first frame, which fades
      and scales it in and is held 700 ms so the animation isn't cut off

### Shell
- [x] One fixed top bar across all three pages — title switches straight to
      the page you swiped to; only page content moves
- [x] Bottom bar: Today / Analytics / Notes, tap or swipe; the pill slides
      with the drag and fades out between tabs
- [x] No back buttons anywhere in the shell

### Today
- [x] Progress card with contextual Wick pose
- [x] Habit card: tinted ground + hairline, rounded icon tile, name,
      description, check control, contribution grid, streak + schedule chips
- [x] Contribution grid — six months of days, month ruler, Tue/Thu/Sat gutter,
      hollow ring on today; fits itself to whatever width it is given
- [x] Tap-to-check-off; countable habits fill the control from the bottom as
      the day's amount climbs, and wrap at the target
- [x] Streak chip in the habit's own unit (days / weeks), dim at zero
- [x] Long-press to reorder, unfinished-first stable sort
- [x] A checked habit settles into the done group — arrives lifted and faded,
      then eases down, instead of teleporting to the bottom
- [x] "Done" divider naming the completed group, shown only at a real boundary
- [x] Three tiers of recognition: toast → milestone → all-done
- [x] Empty state with hero pose + suggestions link

### Habit detail
- [x] No app bar — round buttons floating on the page, the habit's own name is
      the title
- [x] Contribution grid at detail size, tap to backfill, partial shading for
      countable
- [x] Current / best / schedule chips
- [x] Month calendar — Monday-first, six fixed rows, done days filled, noted
      days dotted, month pill and pagers with the future disabled
- [x] One day sheet — hold a grid cell or a calendar day to set the exact
      amount and write a note; tap stays the fast "all of it" backfill
- [x] Notes on a day — offered right after a check-off, never prompted for;
      noted days get a dot in the month calendar, and this habit's notes list
      below it with each day's state, so a note on a missed day still reads as
      one. An empty list is an invitation, not a heading over nothing
- [x] Share a progress card — preview then share, forced light, 3× PNG
- [x] Archive (undoable), delete (undoable, restores position)
- [x] Pops safely if the habit disappears underneath it

### Add & edit
- [x] One sheet for create and edit — close button, centred title, icon hero
      over a clipped wall of the icons it was chosen from
- [x] Colour picker — the reference's 3×7 swatch grid, ringed selection, every
      swatch named for a screen reader; the sheet previews the pick live
- [x] Icon picker — ~250 Lucide icons in six categories, Icon/Emoji tabs,
      search, 8-across grid; the hero and its backdrop wall take the pick and
      the habit's colour immediately
- [x] Name and description, small-caps labels
- [x] "Advanced Options" disclosure hiding frequency, amount and reminder;
      opens already expanded when a habit uses any of them
- [x] Save pinned to the bottom, disabled until the habit has a name
- [x] Frequency stepper 1–7/week, amount stepper 1–99/day
- [x] Emoji kept as the second tab — 60 glyphs, 5 groups, U+FE0F where needed

### Notes
- [x] Notes page — one more swipe past analytics
- [x] Every note, grouped by day, newest first; Today / Yesterday by name
- [x] Each entry shows the habit and that day's state; tap to edit, hold to
      open the habit
- [x] Archived habits keep their notes — the history still happened
- [x] A note on today shows on the habit's tile, and opens from there

### Analytics
- [x] Swipe left from Today
- [x] Habit filter — scope the whole page to one habit or all, held by id;
      each chip wears its habit's colour, so the row doubles as a key
- [x] Filtered to one habit, the whole page takes that habit's colour
- [x] Four stat tiles, two by two, each with its glyph in the corner:
      completion, check-offs, best run, clean days
- [x] Trend card — completion by week, hand-painted area chart, with a chip
      saying how the current week compares to the last
- [x] Completion rate weighted by `perWeek/7`, capped
- [x] `startedOn` so new habits aren't scored for days before they existed
- [x] Consistency grid, 4 steps, marks days before any habit existed; shares
      `GridFrame` with the dashboard and detail grids
- [x] By-weekday bars in a drawn column, so they read against a common ceiling
      instead of floating; silent when spread < 15 points
- [x] By-habit rows with icon, name, rate and bar, each in its own colour

### Settings
- [x] Theme picker System / Light / Dark, persisted; defaults to Light
- [x] Export backup via share sheet
- [x] Import with confirmation; parses before destroying anything
- [x] Archived habits list with restore

### Reminders
- [x] One optional reminder per habit, any time of day
- [x] Suppressed automatically once the habit is done that day
- [x] Permission asked at the moment a reminder is set, not on first launch
- [x] Tap a notification → that habit's detail screen, cold start included
- [x] Re-armed after a reboot
- [x] Never nags an archived habit

### First run
- [x] 3-page onboarding — flame metaphor, backfill (interactive), swipe hint
- [x] Shown once, persisted; blank frame while prefs load
- [x] Starter templates — 19 suggestions, multi-select, never a dead end;
      each carries a colour, so a first run lands on a dashboard that already
      shows what the palette is for

### Accessibility
- [x] Every control labelled and tappable through the semantics tree
- [x] 48 dp tap targets throughout (check control, calendar days, icon
      buttons, FAB tooltip)
- [x] Grids summarised in one label instead of reading every cell — the
      dashboard card speaks a per-habit total, the detail grid stays per-cell
      addressable because its cells can actually be hit
- [x] Palette contrast asserted per swatch, per theme — the check glyph, the
      chip glyph and lit-vs-unlit cells, against real resolved backgrounds
- [x] Passes `androidTapTarget` / `iOSTapTarget` / `labeledTapTarget` /
      `textContrast` guidelines, asserted in `test/a11y_test.dart`

---

## Known gaps — fix before new features

The original five are cleared. The redesign opened one.

- [ ] **Share card still renders the old style.** It is reached from the detail
      header, so tapping share now goes from the redesigned app to a card that
      looks like a different one. `share_card.dart` was out of scope for the
      dashboard-and-detail pass. First item in *Next up*.

- [x] **Compress mascot art** — 4.3 MB → 1.5 MB (palette mode), transparency and
      soft edges intact. `assets/icon/` dropped from the bundle too; it's only
      read by `flutter_launcher_icons` at build time (~520 KB of dead weight).
- [x] **Run on a device** — tested on Android: runs, emoji render, data survives
      a cold kill.
- [x] **Accessibility pass** — see the Accessibility section above.
- [x] **Real `createdAt` field** — recorded on create, with migration that
      recovers it from the timestamp id or the earliest logged day.
- [x] **Keystore** moved to `~/.keystores/wick-release.p12`, referenced from
      `android/key.properties` (mode 600, gitignored). Fingerprint unchanged.
      **Still back it up off-machine** — losing it ends the Play upgrade path.

---

## Backlog

### Next up — in order, and why this order

1. **Share card, redesigned.** *Half a day.* It is the one surface the
   redesign did not reach, it is reachable from the detail header, and it now
   looks like a different app. Rebuild it on `TintCard` + `GridFrame` — the
   reference's share sheet is exactly the habit card on a coloured ground.
   **Blocking nothing, but it ships broken-looking today.**
2. **Dashboard view modes.** *Two days.* The reference's floating pill:
   grid (what we have), compact list (habits × last N days), and mini tiles.
   `GridFrame` already does the third for free and the second is a
   `Table`. Earns its keep the moment someone has more than six habits —
   six full cards is already a lot of scrolling.
3. **Rest days.** *A day.* A day marked "not expected": neither breaks a
   streak nor counts as a miss. The single most-requested habit-tracker
   feature we do not have, and every figure on the analytics page is
   currently slightly wrong for anyone who takes Sundays off.
   Needs a third cell state in `GridCell` and a term in `Analytics.dayScore`.
   **Pick this or streak freeze, not both.**
4. **Reorder screen in Settings.** *An afternoon.* Long-press-to-drag on the
   dashboard is discoverable by accident at best, and it is now the only way
   to reorder. The reference puts an explicit list in Settings. Cheap.
5. **Streak goal.** *A day.* "30 days" as a target, with the chip on the card
   and detail filling toward it. The card already has the chip row; this is a
   field, a progress ring, and one more celebration tier.

### Small — an afternoon, no new dependencies
- [ ] Streak freeze — a monthly miss budget (alternative to rest days, not both)
- [ ] Duplicate a habit
- [ ] All-time best streak across every habit
- [ ] Sort options on Today — by streak / alphabetical / manual
- [ ] Drag across a grid row to backfill several days
- [ ] Flame flicker — idle animation + flare when a streak advances
- [ ] Tap a trend point for that week's figure
- [ ] Sort or group the dashboard by colour, now that colour means something
- [ ] Share card should take the habit's colour — the reference's share sheet
      is the habit card on a ground of its own colour
- [ ] Window picker on analytics — 30 / 90 / 365 days (`Analytics.window`
      already takes it; nothing exposes it)
- [x] Month calendar view on detail
- [x] This week vs. last, on analytics — the trend card's delta chip
- [x] Trend over time — completion by week, `CustomPainter` area chart
- [x] Per-habit colour — 21 swatches, contrast-tested in both themes
- [x] Icon library beyond emoji — Lucide, six categories, search

### Medium — days each
- [ ] Categories — group habits, filter the dashboard and analytics by group
- [ ] Challenges — start/end date + target count, with a finish screen
- [ ] Automatic backups — rolling local snapshot + scheduled export
- [ ] Home screen widget — native Kotlin + Swift; the grid is the whole point
      of the reference's widget and `GridFrame` is already the right shape
- [ ] Localisation — `intl`, locale-aware dates, first-day-of-week (Monday is
      hard-coded in `startOfWeek`, `GridFrame` and `MonthCalendar`)

- [ ] SQLite migration — **only** if measurement demands it

### Large — changes what the product is
- [ ] Cloud sync — ends "data never leaves the phone"; export already covers backup
- [ ] Health integrations — Apple Health / Google Fit
- [ ] Accountability partners — needs everything sync does, plus moderation
- [ ] Watch companion — Wear OS + watchOS

---

## Commands

```sh
flutter test                                  # 181 tests
flutter test --update-goldens                 # after any visual change
flutter analyze
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=symbols/1.0.0   # arm64 is the one to ship
```

Launcher icons are generated, not tracked by hand. After changing
`assets/icon/app_icon.png`, run `dart run flutter_launcher_icons` **and**
regenerate `assets/splash/wick_mark.png` from it, or the mipmaps and the
Flutter launch frame silently keep the old art. Keep that source **RGBA, not
palette-mode**: the generator throws `RangeError` on an indexed PNG, and it
fails only on the iOS step, so Android looks like it worked.

Full-size mascot originals live in `art/mascot-source/` — outside `assets/`, so
they are not bundled. `assets/mascot/` holds the 512 px versions the app ships.

Symbols go to `symbols/<version>/`, not under `build/` — `flutter clean` would
take them, and without them an obfuscated stack trace cannot be read.

Goldens live in `test/goldens/`. They have already caught four real bugs —
a bar-chart overflow, mascots silently not rendering, the hero pose being
unreadable at card size, and a mis-destructured test name. Look at them.

Mascot art is still 1254 px against a 156 px largest use — 1.46 MB of the APK.
Downscaling the sources to 512 px would recover ~1.1 MB. Not done: the art is
the user's, and `cacheHeight` already fixed the runtime memory cost.

Emoji **and Lucide icons** render as fallback boxes in goldens — Flutter's test
renderer paints neither the system COLRv1 emoji font nor bundled icon fonts.
The goldens still catch layout, colour and state; they cannot catch a wrong
glyph. `test/icons_test.dart` covers the catalogue instead. The font really is
bundled — `build/flutter_assets/FontManifest.json` lists it, and a release
build reports the tree-shake. Don't chase the boxes.

After the `habit_tracker` → `wick` rename, a stale `build/linux` CMake cache
still points at the old path. `rm -rf build/linux` if the Linux build errors.
The Dart package name and the Android `applicationId` deliberately still say
`habit_tracker` — changing the applicationId would break the upgrade path for
installed builds.
