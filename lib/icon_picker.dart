import 'package:flutter/material.dart';

import 'emoji.dart';
import 'icons.dart';
import 'theme.dart';

const defaultEmoji = '🔥';

/// What a habit ended up picking: exactly one of the two is set.
class IconChoice {
  const IconChoice.icon(String key)
      : icon = key,
        emoji = '';
  const IconChoice.emoji(String glyph)
      : icon = '',
        emoji = glyph;

  final String icon;
  final String emoji;
}

Future<IconChoice?> showIconPicker(
  BuildContext context, {
  required String icon,
  required String emoji,
}) {
  return showModalBottomSheet<IconChoice>(
    context: context,
    isScrollControlled: true,
    // Tall: this is a browsing sheet, and a half-height one shows two rows.
    constraints: BoxConstraints.tightFor(
        height: MediaQuery.of(context).size.height * 0.86),
    builder: (context) => _IconSheet(icon: icon, emoji: emoji),
  );
}

class _IconSheet extends StatefulWidget {
  const _IconSheet({required this.icon, required this.emoji});

  final String icon;
  final String emoji;

  @override
  State<_IconSheet> createState() => _IconSheetState();
}

class _IconSheetState extends State<_IconSheet> {
  late var _icons = widget.emoji.isEmpty;
  final _query = TextEditingController();
  var _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String get _q => _query.text.trim().toLowerCase();

  /// Matches on the key and on the group name, so "food" finds the whole
  /// group and "coff" finds the one icon.
  Map<String, Map<String, IconData>> get _visibleIcons =>
      _matching(iconGroups, (key, _) => key);

  /// Same, over the emoji set — where the searchable text is the Unicode name
  /// rather than the key, since the key is the glyph itself.
  Map<String, Map<String, String>> get _visibleEmoji =>
      _matching(emojiGroups, (_, name) => name);

  Map<String, Map<String, T>> _matching<T>(
    Map<String, Map<String, T>> groups,
    String Function(String key, T value) text,
  ) {
    final q = _q;
    if (q.isEmpty) return groups;
    final out = <String, Map<String, T>>{};
    for (final group in groups.entries) {
      final hits = <String, T>{
        for (final e in group.value.entries)
          if (text(e.key, e.value).toLowerCase().contains(q) ||
              group.key.toLowerCase().contains(q))
            e.key: e.value,
      };
      if (hits.isNotEmpty) out[group.key] = hits;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = _visibleIcons;
    final emoji = _visibleEmoji;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              RoundIconButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              Expanded(
                child: Center(
                  child: _Segmented(
                    icons: _icons,
                    onChanged: (v) => setState(() => _icons = v),
                  ),
                ),
              ),
              RoundIconButton(
                icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _query.clear();
                }),
                tooltip: _searching ? 'Clear search' : 'Search',
              ),
            ],
          ),
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                  hintText: _icons ? 'Search icons' : 'Search emoji'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        Expanded(
          child: _icons
              ? (groups.isEmpty
                  ? Center(
                      child: Text('No icon matches "${_query.text.trim()}"',
                          style: Theme.of(context).textTheme.bodySmall),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        for (final group in groups.entries) ...[
                          _GroupLabel(group.key),
                          _Grid(
                            children: [
                              for (final e in group.value.entries)
                                _Cell(
                                  selected: e.key == widget.icon,
                                  onTap: () => Navigator.pop(
                                      context, IconChoice.icon(e.key)),
                                  child: Icon(e.value,
                                      size: 22, color: scheme.onSurface),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ))
              : (emoji.isEmpty
                  ? Center(
                      child: Text('No emoji matches "${_query.text.trim()}"',
                          style: Theme.of(context).textTheme.bodySmall),
                    )
                  // Nearly two thousand glyphs: built lazily, a group at a
                  // time, rather than all at once behind a scroll bar.
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: emoji.length,
                      itemBuilder: (context, i) {
                        final group = emoji.entries.elementAt(i);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _GroupLabel(group.key),
                            _Grid(
                              children: [
                                for (final glyph in group.value.keys)
                                  _Cell(
                                    selected: glyph == widget.emoji,
                                    onTap: () => Navigator.pop(
                                        context, IconChoice.emoji(glyph)),
                                    child: Text(glyph,
                                        style: const TextStyle(fontSize: 21)),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    )),
        ),
      ],
    );
  }
}

/// Icon | Emoji. The reference's own control, and the only place the two sets
/// are presented as alternatives rather than as one muddled grid.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.icons, required this.onChanged});

  final bool icons;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Half(label: 'Icon', on: icons, onTap: () => onChanged(true)),
          _Half(label: 'Emoji', on: !icons, onTap: () => onChanged(false)),
        ],
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
          decoration: BoxDecoration(
            color: on ? flameSoftOf(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: on ? flameOf(context) : scheme.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: mono(11.5,
            color: Theme.of(context).colorScheme.secondary,
            weight: FontWeight.w600,
            spacing: 1),
      ),
    );
  }
}

/// Eight across, as the reference lays it out, sized to whatever width there
/// is rather than to a fixed cell.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const columns = 8;
        const gap = 8.0;
        final side = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: side, height: side, child: child),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? flameSoftOf(context) : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: flameOf(context), width: 1.6)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
