import 'package:flutter/material.dart';

// ── Wick palette ────────────────────────────────────────────────────────────
// Navy structures, flame is the brand, and green/purple are reserved for two
// specific meanings: green says "completed", purple says "progress".

const navy = Color(0xFF102A5C);
const navySoft = Color(0xFF294477);
const flame = Color(0xFFFD5500);
const flameYellow = Color(0xFFFDC000);
const candleCream = Color(0xFFFFF9F2);
const warmBg = Color(0xFFFFF8F3);
const warmGray = Color(0xFFD9D6D1);

// Completion and progress are both the inner flame's yellow. Orange stays the
// brand accent — primary actions and streaks — and never fills a chart.
// Content sitting on a yellow fill is navy, never white: white on #FDC000
// fails contrast, and so does yellow *text* on cream.
const success = flameYellow;
const successSoft = Color(0xFFFFF3D6);
const progress = flameYellow;
const progressSoft = successSoft;
const flameSoft = Color(0xFFFFF0E4);

// Dark is not in the brand spec, so it is derived: a neutral black ground —
// navy reads as "unlit blue" at night rather than dark — with each accent
// lifted enough to hold contrast on it. The flame stays the only colour.
const darkBg = Color(0xFF0A0A0A);
const darkCard = Color(0xFF171717);
const darkSunk = Color(0xFF262626);
const darkInk = Color(0xFFFAFAFA);
const darkMuted = Color(0xFFA3A3A3);
const flameDark = Color(0xFFFF7A2E);
const successDark = Color(0xFFFFD24D);
const progressDark = successDark;
const flameSoftDark = Color(0xFF3A2313);
const successSoftDark = Color(0xFF332913);
const progressSoftDark = successSoftDark;

const radius = 16.0;
const pill = 999.0;
const fontFamily = 'PlusJakartaSans';

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Brand accent — the flame. Primary actions, streaks, anything about keeping
/// the habit alive.
Color flameOf(BuildContext c) => isDark(c) ? flameDark : flame;
Color flameSoftOf(BuildContext c) => isDark(c) ? flameSoftDark : flameSoft;

/// Completion. Check marks, finished days, done state.
Color successOf(BuildContext c) => isDark(c) ? successDark : success;
Color successSoftOf(BuildContext c) => isDark(c) ? successSoftDark : successSoft;

/// What sits *on* a completion fill. Navy in both themes — a white glyph on
/// yellow is close to invisible.
const onSuccess = navy;

/// Analytics and progress reporting.
Color progressOf(BuildContext c) => isDark(c) ? progressDark : progress;
Color progressSoftOf(BuildContext c) =>
    isDark(c) ? progressSoftDark : progressSoft;

/// Soft warm shadow. The brand separates surfaces with light, not with rules.
List<BoxShadow> cardShadow(bool dark) => dark
    ? const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 3))]
    : const [BoxShadow(color: Color(0x12102A5C), blurRadius: 16, offset: Offset(0, 3))];

ThemeData appTheme({required bool dark}) {
  final bg = dark ? darkBg : warmBg;
  final card = dark ? darkCard : Colors.white;
  final fg = dark ? darkInk : navy;
  final muted = dark ? darkMuted : navySoft;
  final sunk = dark ? darkSunk : const Color(0xFFF3EEE8);
  final border = dark ? darkSunk : warmGray;
  final accent = dark ? flameDark : flame;

  TextStyle t(double size, FontWeight w, {Color? color, double spacing = -0.2}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: w,
        color: color ?? fg,
        letterSpacing: spacing,
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: bg,
    splashFactory: InkSparkle.splashFactory,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: accent,
      onPrimary: Colors.white,
      secondary: muted,
      onSecondary: bg,
      tertiary: dark ? successDark : success,
      onTertiary: navy,
      surface: card,
      onSurface: fg,
      surfaceContainerHighest: sunk,
      outline: border,
      error: const Color(0xFFDC2626),
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: t(17, FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: sunk,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: t(14, FontWeight.w400, color: muted),
      border: _softBorder(Colors.transparent),
      enabledBorder: _softBorder(Colors.transparent),
      focusedBorder: _softBorder(accent, width: 1.5),
    ),
    // Primary action only — the brand asks that orange stay meaningful.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        textStyle: t(15, FontWeight.w700, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    // Secondary: soft flame tint with navy text, per the brand's button spec.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: dark ? flameSoftDark : flameSoft,
        minimumSize: const Size.fromHeight(52),
        textStyle: t(15, FontWeight.w700),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: muted,
        textStyle: t(14, FontWeight.w600),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: bg,
      surfaceTintColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: t(18, FontWeight.w700),
      contentTextStyle: t(14, FontWeight.w400, color: muted),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? darkCard : navy,
      contentTextStyle: t(14, FontWeight.w600, color: Colors.white),
      actionTextColor: dark ? flameDark : flameYellow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? darkSunk : navy,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: t(11, FontWeight.w600, color: Colors.white),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    textTheme: TextTheme(
      headlineLarge: t(29, FontWeight.w800, spacing: -0.7),
      titleLarge: t(21, FontWeight.w700, spacing: -0.4),
      titleMedium: t(15, FontWeight.w600),
      bodyLarge: t(15, FontWeight.w400),
      bodyMedium: t(14, FontWeight.w400),
      bodySmall: t(13, FontWeight.w400, color: muted),
      labelLarge: t(13, FontWeight.w700),
      labelSmall: t(11.5, FontWeight.w500, color: muted),
    ),
  );
}

/// The note field's own border: rounder than the app's inputs and drawn in the
/// habit's colour, so the box reads as part of the habit rather than as a form
/// control that wandered in.
OutlineInputBorder noteBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );

OutlineInputBorder _softBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderSide: BorderSide(color: color, width: width),
      borderRadius: BorderRadius.circular(14),
    );

const months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const weekdayShort = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

String longDate(DateTime d) =>
    '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';

String shortDate(DateTime d) => '${months[d.month - 1]} ${d.day}, ${d.year}';

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// A card the way the brand draws one: no border, soft shadow, large radius.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: cardShadow(isDark(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ── Per-habit colour ────────────────────────────────────────────────────────
// Twenty-one swatches in the reference app's 3×7 grid, warmed through the
// reds, oranges and magentas to sit with the flame. One value per swatch, the
// same in both themes — these ARE the palette, and darkening them for light
// mode was tried and looked like mud.
//
// The catch, and why `gridWell` below exists: every one of these is a light
// colour. On cream, a lit cell and an unlit one are both light, so no choice
// of alpha gets them 3:1 apart — the worst pair measures 1.26 and the maths
// does not care how it is tuned. These colours need a dark ground, which is
// what the reference gives them. So the grid keeps its own dark well in
// *both* themes, and the lit-vs-unlit gap comes back to 3.98.
//
// Measured, not guessed, against the surfaces these actually resolve to:
//   lit cell vs. unlit, in the well  ≥ 3.98 light, 4.93 dark  (need 3.0)
//   glyph on a full-strength fill    ≥ 4.67                   (need 4.5)
//   chip text on its own ground      ≥ 4.67                   (need 4.5)
// Asserted per swatch in `test/palette_test.dart`; adding one without a check
// is how this quietly stops being true.

class HabitColor {
  const HabitColor(this.name, this.value);

  final String name;
  final Color value;
}

const habitColors = <HabitColor>[
  HabitColor('Red', Color(0xFFFF6B6B)),
  HabitColor('Orange', Color(0xFFFF9138)),
  HabitColor('Amber', Color(0xFFFFBE2E)),
  HabitColor('Yellow', Color(0xFFFFD11A)),
  HabitColor('Lime', Color(0xFFA3E635)),
  HabitColor('Green', Color(0xFF4ADE80)),
  HabitColor('Emerald', Color(0xFF34D399)),
  HabitColor('Teal', Color(0xFF2DD4BF)),
  HabitColor('Cyan', Color(0xFF22C7E5)),
  HabitColor('Sky', Color(0xFF38B5E8)),
  HabitColor('Blue', Color(0xFF60A5FA)),
  HabitColor('Indigo', Color(0xFF818CF8)),
  HabitColor('Violet', Color(0xFFA78BFA)),
  HabitColor('Purple', Color(0xFFC084FC)),
  HabitColor('Fuchsia', Color(0xFFD86FE8)),
  HabitColor('Pink', Color(0xFFEC6AAE)),
  HabitColor('Rose', Color(0xFFF76B83)),
  HabitColor('Slate', Color(0xFF94A3B8)),
  HabitColor('Gray', Color(0xFF9CA3AF)),
  HabitColor('Neutral', Color(0xFFA3A3A3)),
  HabitColor('Stone', Color(0xFFA8A29E)),
];

/// Orange — the palette's Wick-adjacent hue, and what a habit is before anyone
/// picks. Out-of-range indexes land here too, so a hand-edited or future
/// export can never colour a habit with a crash.
const defaultHabitColor = 1;

Color habitColorAt(int index) =>
    habitColors[index.clamp(0, habitColors.length - 1)].value;

/// Carries one habit's colour down its subtree. Every tint helper below reads
/// it, so a card wraps itself once and its icon tile, grid, chips, border and
/// check control all follow — instead of each of them taking a `Color`
/// parameter that has to be threaded through six widgets.
///
/// Absent — the shell, settings, onboarding, anything not about one specific
/// habit — means the brand flame, exactly as before.
class HabitAccent extends InheritedWidget {
  const HabitAccent({super.key, required this.color, required super.child});

  final Color color;

  static Color? maybeOf(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<HabitAccent>()?.color;

  @override
  bool updateShouldNotify(HabitAccent old) => old.color != color;
}

/// The colour of whatever we are inside: a habit's own, or the brand flame.
Color accentOf(BuildContext c) => HabitAccent.maybeOf(c) ?? flameOf(c);

/// A colour that can carry small text against a tinted well.
///
/// At night that is the accent itself. In light it is not, and cannot be: the
/// palette's light values top out around 3.9:1 against the 12% wells they sit
/// in, short of the 4.5 a 12 px label needs. This is the same rule the brand
/// already sets for yellow — the fill and the glyph carry the colour, and the
/// text takes the normal foreground and lets weight do the work.
Color onTint(BuildContext c) =>
    isDark(c) ? accentOf(c) : Theme.of(c).colorScheme.onSurface;

/// WCAG relative contrast between two opaque colours.
double contrastBetween(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// What goes *on* a full-strength accent fill — a check mark, a count.
///
/// Whichever of the two actually wins, not whichever a lightness threshold
/// guesses: a mid-luminance swatch like Tailwind's red-400 reads as "dark" to
/// a threshold and gets white, when navy is the clearer of the two by a full
/// point. Measuring costs two luminance calls and is never wrong.
///
/// Navy rather than black, because it is the brand's ink and it looks like the
/// rest of the app. Computed rather than tabulated: the palette is light at
/// night and dark by day, so the answer flips per swatch per theme, and a
/// 42-entry table would drift out of step with the colours above.
Color onAccent(BuildContext c) {
  final a = accentOf(c);
  return contrastBetween(navy, a) >= contrastBetween(Colors.white, a)
      ? navy
      : Colors.white;
}

// ── HabitKit-style surfaces ─────────────────────────────────────────────────
// Every habit card is a wash of the brand flame over the page ground: a faint
// fill, a slightly stronger hairline, and a grid whose lit cells are the flame
// at full strength. One hue across the whole dashboard — the reference app
// gives each habit its own colour, Wick's brand does not.

/// The current accent at [alpha], for fills and hairlines that have to read as
/// tint rather than as a second colour. Everything below is built on it, so
/// wrapping a subtree in [HabitAccent] recolours all of it at once.
Color tint(BuildContext c, double alpha) =>
    accentOf(c).withValues(alpha: alpha);

/// Card ground. Barely there in light, where a wash on cream goes muddy fast.
Color cardTint(BuildContext c) => tint(c, isDark(c) ? 0.07 : 0.035);

/// The hairline around a card, and around the grid well inside it.
Color cardEdge(BuildContext c) => tint(c, isDark(c) ? 0.16 : 0.13);

/// The panel a contribution grid sits in. On cream there is no panel: the
/// grid sits straight on the card, one ground for the whole thing — which also
/// means the card's hover and press ink reach it. Dark mode keeps a well; the
/// palette needs a ground darker than the card to be seen against.
Color gridWell(BuildContext c) =>
    isDark(c) ? Color.alphaBlend(tint(c, 0.07), darkBg) : Colors.transparent;

/// An unlit grid cell — present, clearly not filled. Always read against
/// [gridWell], never against the page. Heavier on cream: the well is light
/// there, so a 16% wash of the swatch would barely register as a cell.
Color cellEmpty(BuildContext c) => tint(c, isDark(c) ? 0.16 : 0.26);

/// Grid furniture: month names and weekday initials. Dimmed white in the dark
/// well, muted navy on the cream one — `secondary` at full strength competes
/// with the cells it labels.
Color gridLabel(BuildContext c) => isDark(c)
    ? Colors.white.withValues(alpha: 0.45)
    : navySoft.withValues(alpha: 0.85);

/// Icon tiles and chips sit one step up from the card ground.
Color chipFill(BuildContext c) => tint(c, isDark(c) ? 0.15 : 0.12);

/// Small labels — month names, weekday initials, streak counts, "Aug 2026".
/// Monospace on purpose: the reference sets every number and short label in
/// one, and it is what makes a wall of digits read as data rather than prose.
/// The family is the platform's own, so nothing has to be bundled.
const monoFamily = 'monospace';

TextStyle mono(
  double size, {
  required Color color,
  FontWeight weight = FontWeight.w500,
  double spacing = 0.4,
}) =>
    TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
    );

/// A round icon button in a soft well — the reference's header control, and
/// the only chrome shape it uses for navigation.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.filled = false,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  /// Primary action — the flame disc rather than the neutral well.
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onPressed,
        child: Material(
          color: filled
              ? flameOf(context)
              : (isDark(context) ? darkSunk : const Color(0xFFF0E9E1)),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: size * 0.5,
                color: filled ? Colors.white : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card every habit lives in: tinted ground, hairline edge, no shadow.
/// The reference separates cards from the page with tint, not elevation.
class TintCard extends StatelessWidget {
  const TintCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Overrides the tinted ground while keeping the accent's hairline — for a
  /// card that wants the colour at its edge but not under its content.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Over the *page* ground, not the raised surface colour: these cards
        // are told apart from the page by their tint and hairline, the way the
        // reference does it, so starting them a step lighter would undo that.
        color: color ??
            Color.alphaBlend(
                cardTint(context), Theme.of(context).scaffoldBackgroundColor),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardEdge(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A pill of mutually exclusive choices — the settings sheets' one picker
/// shape. Selected is the flame; the rest stay quiet.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  /// Choice -> label, in the order they should read.
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(pill),
      ),
      child: Row(
        children: options.entries.map((e) {
          final selected = value == e.key;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: e.value,
              excludeSemantics: true,
              onTap: () => onChanged(e.key),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? flameOf(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(pill),
                  ),
                  child: Text(
                    e.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : scheme.secondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A small pill: tinted well, flame glyph, mono label. Streak counts and
/// schedules on both the card and the detail screen.
class TintChip extends StatelessWidget {
  const TintChip({
    super.key,
    required this.icon,
    required this.label,
    this.semanticsLabel,
    this.dim = false,
  });

  final IconData icon;
  final String label;
  final String? semanticsLabel;

  /// Nothing to boast about yet — a zero streak reads muted rather than lit.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // The unlit grid cell's own ground, with the accent as ink for both glyph
    // and label — the chip and the grid below it then read as one surface.
    // Deliberately below the 4.5:1 a 12 px label normally wants on cream,
    // where the palette is light: the semantics label carries the same words
    // for anyone who cannot read them off the pill.
    final ground = dim ? scheme.surfaceContainerHighest : cellEmpty(context);
    final ink = dim ? scheme.secondary : accentOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ink),
          const SizedBox(width: 5),
          Text(
            label,
            semanticsLabel: semanticsLabel,
            style: mono(12, color: ink, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
