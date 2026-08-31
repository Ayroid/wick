#!/usr/bin/env python3
"""Regenerate lib/emoji.dart from Unicode's emoji-test.txt.

    python3 tool/gen_emoji.py [path-to-emoji-test.txt(.gz)]

Defaults to the copy Fedora ships with ibus-typing-booster; otherwise grab
https://unicode.org/Public/emoji/latest/emoji-test.txt and pass it in.
"""
import collections
import gzip
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else \
    '/usr/share/ibus-typing-booster/data/emoji-test.txt.gz'
OUT = 'lib/emoji.dart'


def read(path):
    opener = gzip.open if path.endswith('.gz') else open
    return opener(path, 'rt', encoding='utf-8')


def parse(path):
    groups = collections.OrderedDict()
    group = None
    for line in read(path):
        line = line.rstrip('\n')
        if line.startswith('# group:'):
            group = line.split(':', 1)[1].strip()
            groups.setdefault(group, {})
            continue
        if not line or line.startswith('#'):
            continue
        _, rest = line.split(';', 1)
        status, _, comment = rest.partition('#')
        # Fully-qualified only: the minimally-qualified and unqualified forms
        # are the same emoji missing its variation selector.
        if status.strip() != 'fully-qualified':
            continue
        glyph, name = comment.strip().split(' ', 1)
        head, _, tail = name.partition(' ')
        if head.startswith('E') and head[1:].replace('.', '').isdigit():
            name = tail
        # One entry per emoji — the picker is not a modifier keyboard.
        if 'skin tone' in name:
            continue
        groups[group][glyph] = name
    return {g: v for g, v in groups.items() if v}


def quote(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', r'\$') + "'"


def main():
    groups = parse(SRC)
    out = ['''// GENERATED — do not edit by hand.
//
// The full Unicode emoji set (emoji-test.txt, Unicode 17.0), in Unicode's own
// groups and order, fully-qualified sequences only and one entry per emoji —
// the skin-tone variants of a sequence are dropped, since the picker offers a
// habit one glyph, not a modifier keyboard.
//
// Regenerate with `tool/gen_emoji.py` when a new Unicode release lands.

/// Every emoji by group, each mapped to its Unicode name — the name is what
/// the picker's search matches on.
const emojiGroups = <String, Map<String, String>>{''']
    for group, entries in groups.items():
        out.append('  %s: {' % quote(group))
        for glyph, name in entries.items():
            out.append('    %s: %s,' % (quote(glyph), quote(name)))
        out.append('  },')
    out.append('};')
    out.append('')
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out))
    print('%s: %d groups, %d emoji' %
          (OUT, len(groups), sum(len(v) for v in groups.values())))


if __name__ == '__main__':
    main()
