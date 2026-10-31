#!/bin/bash
# Regenerate the Miku theme's colors from the current wallpaper.
# Omarchy-compatible: writes to current/theme/ and live-recolors
# running terminals. Does NOT edit the theme directory.
#
# Usage:  recolor-omarchy.sh
set -u

THEME_DIR="$(cd "$(dirname "$0")" && pwd)"
CURRENT_THEME="$HOME/.local/state/omarchy/current/theme"

# Find the current wallpaper
wall="$HOME/.local/state/omarchy/current/background"
[ -L "$wall" ] && wall=$(readlink -f "$wall")
[ -f "$wall" ] || { echo "wallpaper not found: $wall" >&2; exit 1; }
wallname=$(basename "$wall")

json=$(mktemp); trap 'rm -f "$json"' EXIT

echo "[miku] extracting colors from: $wallname"
matugen image -m smart --source-color-index 0 -j hex --dry-run -q "$wall" >"$json" 2>/dev/null || {
  echo "[miku] matugen failed" >&2; exit 1
}

# Generate colors to a temp file (doesn't touch the theme dir)
tmp_colors=$(mktemp); trap 'rm -f "$json" "$tmp_colors"' EXIT
python3 "$THEME_DIR/recolor.py" "$json" "$tmp_colors" || exit 1

# Copy into current/theme/ (where apps already read from)
cp "$tmp_colors" "$CURRENT_THEME/colors.toml"

# Regenerate foot.ini from the new colors (strip # from hex for foot format)
python3 -c "
import sys
colors = {}
for line in open(sys.argv[1]):
    line = line.strip()
    if '=' in line and not line.startswith('#') and not line.startswith('['):
        k, v = line.split('=', 1)
        colors[k.strip()] = v.strip().strip('\"')
def strip(h): return h.lstrip('#')
def s(h):
    v = colors.get(h, '000000')
    return v.lstrip('#')
accent = s('accent')
bg = s('background')
fg = s('foreground')
lines = [
    '[colors-dark]',
    'foreground=' + fg,
    'background=' + bg,
    'selection-foreground=' + bg,
    'selection-background=' + accent,
    '',
    'cursor=' + bg + ' ' + s('bright_foreground'),
    '',
    'regular0=' + bg,
    'regular1=' + s('red'),
    'regular2=' + s('green'),
    'regular3=' + s('yellow'),
    'regular4=' + s('blue'),
    'regular5=' + s('magenta'),
    'regular6=' + s('cyan'),
    'regular7=' + fg,
    '',
    'bright0=' + s('muted'),
    'bright1=' + s('bright_red'),
    'bright2=' + s('bright_green'),
    'bright3=' + s('bright_yellow'),
    'bright4=' + s('bright_blue'),
    'bright5=' + s('bright_magenta'),
    'bright6=' + s('bright_cyan'),
    'bright7=' + s('bright_foreground'),
]
open(sys.argv[2], 'w').write('\n'.join(lines) + '\n')
" "$tmp_colors" "$CURRENT_THEME/foot.ini"

# Live-recolor running foot terminals via OSC sequences
python3 -c "
import sys
colors = {}
for line in open(sys.argv[1]):
    line = line.strip()
    if '=' in line and not line.startswith('#') and not line.startswith('['):
        k, v = line.split('=', 1)
        colors[k.strip()] = v.strip().strip('\"')
def h(k):
    v = colors.get(k, '#000000')
    return v
osc = ''
osc += '\033]11;' + h('background') + '\007'
osc += '\033]10;' + h('foreground') + '\007'
osc += '\033]12;' + h('bright_foreground') + '\007'
osc += '\033]17;' + h('accent') + '\007'
osc += '\033]19;' + h('background') + '\007'
pairs = [
    ('background', 0), ('red', 1), ('green', 2), ('yellow', 3),
    ('blue', 4), ('magenta', 5), ('cyan', 6), ('foreground', 7),
    ('muted', 8), ('bright_red', 9), ('bright_green', 10),
    ('bright_yellow', 11), ('bright_blue', 12), ('bright_magenta', 13),
    ('bright_cyan', 14), ('bright_foreground', 15),
]
for name, idx in pairs:
    osc += '\033]4;' + str(idx) + ';' + h(name) + '\007'
sys.stdout.write(osc)
" "$tmp_colors" > /tmp/miku-osc

# Send OSC to all foot terminals
for p in $(pgrep -x foot 2>/dev/null); do
  for c in $(pgrep -P "$p" 2>/dev/null); do
    t=$(readlink "/proc/$c/fd/1" 2>/dev/null)
    case "$t" in /dev/pts/*) cat /tmp/miku-osc > "$t" 2>/dev/null ;; esac
  done
done
rm -f /tmp/miku-osc

# Restart btop theme
pkill -SIGUSR2 btop 2>/dev/null

echo "[miku] done. colors updated + terminals recolored."
