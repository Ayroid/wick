import 'package:flutter/material.dart';

import 'theme.dart';

/// Wick's poses. Each maps to one asset in `assets/mascot/`.
///
/// There is deliberately no "disappointed" pose: a missed day dims the flame,
/// it never turns Wick against the person using the app.
enum Wick {
  standing('wick_default'),
  focus('wick_focus'),
  complete('wick_complete'),
  thinking('wick_thinking'),
  celebrate('wick_celebrate'),
  rest('wick_rest');

  const Wick(this.asset);

  final String asset;

  String get path => 'assets/mascot/$asset.png';

  /// Shown if this pose's artwork isn't present yet.
  Wick? get fallback => this == Wick.standing ? Wick.focus : null;
}

class WickImage extends StatelessWidget {
  const WickImage(this.pose, {super.key, this.size = 72, this.semanticLabel});

  final Wick pose;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Height, not a square box: the poses don't share an aspect ratio, and
    // constraining width too would render the wider ones visibly shorter.
    return Image.asset(
      pose.path,
      height: size,
      fit: BoxFit.fitHeight,
      // The art is ~1250 px; the biggest on-screen use is 156. Decoding at
      // display size keeps a few MB per pose out of the image cache and stops
      // the downsample from drifting between runs.
      cacheHeight:
          (size * MediaQuery.devicePixelRatioOf(context)).round(),
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      // A missing pose degrades to its stand-in rather than a hole in the
      // layout — and never takes the screen down with it.
      errorBuilder: (context, _, _) => pose.fallback == null
          ? SizedBox(height: size)
          : WickImage(pose.fallback!, size: size, semanticLabel: semanticLabel),
    );
  }
}

/// The streak flame, sized by how strong the run is. A broken streak still
/// burns — smaller and dimmer, never out.
class FlameMark extends StatelessWidget {
  const FlameMark({super.key, required this.streak, this.size = 16});

  final int streak;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (scale, opacity) = switch (streak) {
      0 => (0.78, 0.45),
      < 3 => (0.9, 0.8),
      < 7 => (1.0, 1.0),
      < 30 => (1.12, 1.0),
      _ => (1.24, 1.0),
    };

    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: Size(size * scale * 0.8, size * scale),
        painter: _FlamePainter(
          sparkle: streak >= 30,
          outline: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Drawn rather than shipped as an asset: it has to scale with the streak and
/// recolour with the theme, which a PNG can't do.
class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.sparkle, required this.outline});

  final bool sparkle;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    final outer = Path()
      ..moveTo(w * .5, 0)
      ..cubicTo(w * .5, h * .22, w, h * .3, w, h * .62)
      ..cubicTo(w, h * .87, w * .78, h, w * .5, h)
      ..cubicTo(w * .22, h, 0, h * .87, 0, h * .62)
      ..cubicTo(0, h * .3, w * .5, h * .22, w * .5, 0)
      ..close();

    canvas.drawPath(outer, Paint()..color = flame);

    final inner = Path()
      ..moveTo(w * .5, h * .38)
      ..cubicTo(w * .5, h * .5, w * .82, h * .56, w * .82, h * .72)
      ..cubicTo(w * .82, h * .89, w * .68, h * .97, w * .5, h * .97)
      ..cubicTo(w * .32, h * .97, w * .18, h * .89, w * .18, h * .72)
      ..cubicTo(w * .18, h * .56, w * .5, h * .5, w * .5, h * .38)
      ..close();

    canvas.drawPath(inner, Paint()..color = flameYellow);

    if (sparkle) {
      final dot = Paint()..color = flameYellow;
      canvas.drawCircle(Offset(w * 1.05, h * .18), w * .09, dot);
      canvas.drawCircle(Offset(-w * .08, h * .42), w * .07, dot);
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.sparkle != sparkle || old.outline != outline;
}

/// Wick with a line of encouragement, for empty states and quiet moments.
class WickMessage extends StatelessWidget {
  const WickMessage({
    super.key,
    required this.pose,
    required this.headline,
    this.body,
    this.action,
    this.size = 132,
  });

  final Wick pose;
  final String headline;
  final String? body;
  final Widget? action;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WickImage(pose, size: size, semanticLabel: 'Wick the candle'),
        const SizedBox(height: 18),
        Text(headline, textAlign: TextAlign.center, style: text.titleLarge),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(body!, textAlign: TextAlign.center, style: text.bodySmall),
        ],
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    );
  }
}

/// The celebration moment: all of today's habits done, or a streak milestone.
/// Deliberately a single tap to dismiss and no scoring — recognition, not
/// gamification.
Future<void> showWickMoment(
  BuildContext context, {
  required Wick pose,
  required String headline,
  required String body,
  /// Offered alongside "Keep going" when there's a day worth writing about.
  /// A milestone is exactly when someone has something to say, so the note
  /// offer must not be lost to the celebration that replaced the toast.
  VoidCallback? onNote,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: navy.withValues(alpha: 0.32),
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WickImage(pose, size: 148),
            const SizedBox(height: 16),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 24,
                    color: flameOf(context),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep going'),
            ),
            if (onNote != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onNote();
                },
                child: const Text('Add note'),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Streaks worth stopping the person for. Anything more often is nagging.
const streakMilestones = {7, 14, 30, 50, 100, 200, 365};

String milestoneHeadline(int streak, bool weekly) =>
    weekly ? '$streak weeks strong!' : '$streak days strong!';
