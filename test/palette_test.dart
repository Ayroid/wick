import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/theme.dart';

/// WCAG relative-contrast between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// [fg] at [alpha] painted over [bg] — what a tinted well actually resolves to.
Color over(Color fg, double alpha, Color bg) =>
    Color.alphaBlend(fg.withValues(alpha: alpha), bg);

void main() {
  // The palette is the reference app's, and its values are tuned for a dark
  // ground. Wick renders them on cream too, so every swatch carries a second
  // value — and the point of the pair is that both survive contact with a real
  // background. A swatch added without a partner dark enough for light mode
  // fails here rather than shipping as unreadable.
  group('every swatch holds up in both themes', () {
    for (final swatch in habitColors) {
      test(swatch.name, () {
        final c = swatch.value;

        // Whatever sits on a full-strength fill — the check mark, a count, a
        // chip label on cream. Same rule `onAccent` uses: the better ink wins.
        final ink =
            contrast(navy, c) >= contrast(Colors.white, c) ? navy : Colors.white;
        expect(contrast(ink, c), greaterThanOrEqualTo(4.5),
            reason: '${swatch.name}: the check glyph fails on its own fill');

        for (final dark in [true, false]) {
          final where = '${swatch.name} (${dark ? "dark" : "light"})';
          // The grid's own ground and the two cells drawn on it. At night that
          // ground is a dark well; on cream the grid sits straight on the card
          // — see `gridWell`.
          final card = over(c, dark ? 0.07 : 0.035, dark ? darkBg : warmBg);
          final well = card;
          final empty = over(c, dark ? 0.16 : 0.26, well);

          // A done day against a missed one. This is the whole grid. On cream
          // both are the swatch — the chosen colour, at full strength against a
          // wash of itself — so the gap there is saturation, not luminance, and
          // the 3:1 rule the dark well was built for cannot be met without
          // darkening the colour the user picked. It is decoration, not text.
          expect(contrast(c, empty), greaterThanOrEqualTo(dark ? 3.0 : 1.15),
              reason: '$where: a lit cell is not distinct from an unlit one');

          // Grid furniture has to stay legible on that same ground.
          final label = dark ? Colors.white : over(navySoft, 0.85, well);
          expect(contrast(label, well), greaterThanOrEqualTo(4.5),
              reason: '$where: month and weekday labels are lost in the well');
        }

        // At night the chip is the reference's: accent ink on a faint well of
        // itself. On cream it inverts — see TintChip.
        final darkWell = over(c, 0.15, over(c, 0.07, darkBg));
        expect(contrast(c, darkWell), greaterThanOrEqualTo(4.5),
            reason: '${swatch.name}: chip text is lost in its own well');
      });
    }
  });

  test('the reference palette is intact — 21 swatches, 3 rows of 7', () {
    expect(habitColors, hasLength(21));
    expect(habitColors.length % 7, 0);
    expect(habitColors.map((c) => c.name).toSet(), hasLength(21));
  });

  test('the default is a real swatch', () {
    expect(defaultHabitColor, inInclusiveRange(0, habitColors.length - 1));
  });

  test('an out-of-range index clamps instead of crashing', () {
    // Stored data is a hand-editable JSON export; a bad index must not be able
    // to take the app down.
    for (final i in [-99, -1, 21, 9999]) {
      expect(() => habitColorAt(i), returnsNormally);
    }
    expect(habitColorAt(-1), habitColors.first.value);
    expect(habitColorAt(9999), habitColors.last.value);
  });

  test('every swatch is distinct', () {
    expect(habitColors.map((c) => c.value).toSet(), hasLength(21));
  });

  test('the palette is light throughout — which is why the well is dark', () {
    // If a swatch ever arrives dark enough to read on cream, the grid well
    // stops being necessary for it and this assumption needs revisiting.
    for (final c in habitColors) {
      expect(c.value.computeLuminance(), greaterThan(0.25),
          reason: '${c.name} is darker than the palette this was built for');
    }
  });
}
