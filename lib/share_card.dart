import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'detail.dart' show toast;
import 'grid.dart';
import 'store.dart';
import 'theme.dart';
import 'wick.dart';

/// Preview-then-share, rather than capturing offscreen: the person sees the
/// exact image that leaves the phone before it does, and the card is already
/// painted by the time they press the button.
Future<void> showShareCard(
  BuildContext context,
  Habit habit,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Floating, like the note sheet: the card being previewed is an image with
    // its own edges, and a sheet welded to the bottom of the screen fought it.
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Material(
        color: Theme.of(context).bottomSheetTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: _SharePreview(habit: habit),
      ),
    ),
  );
}

class _SharePreview extends StatefulWidget {
  const _SharePreview({required this.habit});

  final Habit habit;

  @override
  State<_SharePreview> createState() => _SharePreviewState();
}

class _SharePreviewState extends State<_SharePreview> {
  final _boundary = GlobalKey();
  var _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final png = await _capture();
      final dir = await Directory.systemTemp.createTemp('wick_card');
      final file = File('${dir.path}/wick-${dayKey(today())}.png');
      await file.writeAsBytes(png);
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: _caption(widget.habit),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'Could not build the card: $e');
      }
    }
  }

  Future<Uint8List> _capture() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // 3× so the card is sharp wherever it lands, not just on this screen.
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The card always renders light — it is going somewhere with its own
          // background, and cream reads as Wick's regardless of the OS theme.
          // Forced light, not the app's theme: anything inside that recolours
          // with brightness (FlameMark's outline) would otherwise come out
          // near-white on the cream card in dark mode.
          RepaintBoundary(
            key: _boundary,
            child: Theme(
              data: appTheme(dark: false),
              child: ShareCard(habit: widget.habit),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(_busy ? 'Preparing…' : 'Share'),
          ),
        ],
      ),
    );
  }
}

String _caption(Habit h) {
  final unit = h.isWeekly ? 'week' : 'day';
  final n = h.streak;
  if (n == 0) return '${h.name} — back at it with Wick.';
  return '$n $unit${n == 1 ? "" : "s"} of ${h.name}, kept going with Wick.';
}

/// The image itself. Fixed sizes, not theme text styles — this is a picture
/// with its own layout, and it must look the same on every device.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final n = habit.streak;
    final unit = habit.isWeekly ? (n == 1 ? 'week' : 'weeks') : (n == 1 ? 'day' : 'days');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: candleCream,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: warmGray),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const WickImage(Wick.celebrate, size: 68),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$n',
                          style: const TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 46,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: navy,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          unit,
                          style: const TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: navySoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      habit.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // The same grid the app draws, in the habit's own colour — it says
          // more than a caption could, and it is what the card is about.
          HabitAccent(
            color: habitColorAt(habit.color),
            child: ContributionGrid(
              habit: habit,
              cell: 9,
              gap: 3,
              showMonths: true,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlameMark(streak: n, size: 14),
              const SizedBox(width: 6),
              const Text(
                'Wick',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: navySoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
