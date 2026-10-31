#!/bin/bash
# Regenerate the Miku theme's colors from the current wallpaper.
# The launcher picks up the new colors automatically, no restart needed.
#
# Usage:  recolor.sh
#
# How it works:
#   1. Extract colors from the current wallpaper (matugen)
#   2. Write colors.toml (Miku-tinted palette)
#   3. Symlink the wallpaper into the theme's backgrounds
#   4. Cycle style.toml: miku -> tokyo-night -> miku to force the launcher
#      to re-read colors.toml via followStyle(). The "# recolor-<timestamp>"
#      comment makes the final text differ from the original, bypassing
#      distinctUntilChanged(). If the launcher misses the cycle (FileObserver
#      is flaky), retry with a longer delay.
set -u

THEME_DIR="$(cd "$(dirname "$0")" && pwd)"
THEME_NAME="miku"
STYLE="$HOME/.config/omalauncher/style/style.toml"
STATE="$HOME/.local/state/omarchy/current/theme.name"

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

# Symlink wallpaper into theme backgrounds
mkdir -p "$THEME_DIR/backgrounds"
ln -sf "$wall" "$THEME_DIR/backgrounds/$wallname"

# Generate colors
python3 "$THEME_DIR/recolor.py" "$json" "$THEME_DIR/colors.toml" || exit 1

# Copy to user override (takes precedence over built-in)
user_dir="$HOME/.config/omarchy/themes/$THEME_NAME"
mkdir -p "$user_dir/backgrounds"
cp "$THEME_DIR/colors.toml" "$user_dir/colors.toml"
ln -sf "$wall" "$user_dir/backgrounds/$wallname"

# Theme cycle to force the launcher to re-read colors.toml.
# Uses a non-existent theme name so the launcher never applies it —
# no visible flash. The name change still triggers followStyle(),
# and the switch back to miku reads the new colors.toml.
ts=$(date +%s)

# Try the cycle, verify the launcher applied miku, retry if not.
# Single 0.1s delay.
for delay in 0.1; do
  sed -i "s/^theme = .*/theme = \"miku-$ts\"/; s/^background = .*/background = \"$wallname\"/" "$STYLE"
  sleep 0.1
  sed -i "s/^theme = .*/theme = \"$THEME_NAME\"/" "$STYLE"
  sed -i "s/^background = .*/background = \"$wallname\" # recolor-${ts}-$$/" "$STYLE"

  # Give the launcher a moment to process, then verify
  sleep 2
  applied=$(cat "$STATE" 2>/dev/null)
  if [ "$applied" = "$THEME_NAME" ]; then
    echo "[miku] done (delay ${delay}s). new colors active."
    exit 0
  fi
  echo "[miku] retry (delay ${delay}s) — launcher still on: $applied"
done

echo "[miku] warning: launcher didn't confirm miku after 3 attempts."
echo "[miku] colors are written; restart the launcher to apply."
