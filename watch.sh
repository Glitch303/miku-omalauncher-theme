#!/bin/bash
# Watches the active wallpaper and regenerates the Miku theme when it changes.
#
# - Only acts when miku is the currently selected theme in style.toml
# - When the theme switches back to miku, regenerates from the current wallpaper
# - While recolor.sh is cycling the theme (miku→tokyo-night→miku), the watcher
#   ignores theme changes but still tracks the wallpaper
#
# Usage:
#   Start:  nohup ~/.local/share/omarchy/themes/miku/watch.sh &>/dev/null &
#   Stop:   pkill -f "miku.*watch.sh"
#   Log:    ~/.local/state/omalauncher/miku-watch.log
set -u

THEME_DIR="$(cd "$(dirname "$0")" && pwd)"
THEME_NAME="miku"
WALL="$HOME/.local/state/omarchy/current/background"
STYLE="$HOME/.config/omalauncher/style/style.toml"
STATE_DIR="$HOME/.local/state/omalauncher"
LOCK="$STATE_DIR/miku-lock"
LOG="$STATE_DIR/miku-watch.log"

mkdir -p "$STATE_DIR"

log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }

last_wall=""
last_theme=""
cycling=0  # 1 while recolor.sh is running

while true; do
  sleep 1
  cur_theme=$(grep '^theme' "$STYLE" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
  cur_wall=$(readlink -f "$WALL" 2>/dev/null)

  # While recolor.sh is running, just track state — don't trigger anything
  if [ -f "$LOCK" ]; then
    # Still cycling; don't update last_theme so we don't see a false
    # "theme switched to miku" when the cycle finishes
    [ -n "$cur_wall" ] && last_wall="$cur_wall"
    continue
  fi

  # miku-* is our cycle target (non-existent theme) — no trigger
  case "$cur_theme" in
    miku-*)
      last_theme="$cur_theme"
      [ -n "$cur_wall" ] && last_wall="$cur_wall"
      continue
      ;;
  esac

  # Case 1: theme just switched to miku (user action, not our cycle) → regenerate
  if [ "$cur_theme" = "$THEME_NAME" ] && [ "$last_theme" != "$THEME_NAME" ] && [ "$cycling" -eq 0 ] && [ -n "$cur_wall" ] && [ -f "$cur_wall" ]; then
    log "theme->$THEME_NAME, wallpaper: $(basename "$cur_wall")"
    echo $$ > "$LOCK"
    cycling=1
    bash "$THEME_DIR/recolor.sh" >> "$LOG" 2>&1
    rm -f "$LOCK"
    cycling=0
    last_wall="$cur_wall"
    last_theme="$THEME_NAME"
    continue
  fi

  # Case 2: wallpaper changed while miku is active → regenerate
  if [ "$cur_theme" = "$THEME_NAME" ] && [ -n "$cur_wall" ] && [ "$cur_wall" != "$last_wall" ] && [ -f "$cur_wall" ]; then
    log "wallpaper: $(basename "$cur_wall")"
    echo $$ > "$LOCK"
    cycling=1
    bash "$THEME_DIR/recolor.sh" >> "$LOG" 2>&1
    rm -f "$LOCK"
    cycling=0
    last_wall="$cur_wall"
    last_theme="$THEME_NAME"
    continue
  fi

  # Not on miku: track state. If we were cycling and now the theme is miku
  # again (cycle finished), reset cycling so the next wallpaper change works.
  if [ "$cycling" -eq 1 ] && [ "$cur_theme" = "$THEME_NAME" ]; then
    cycling=0
  fi
  last_theme="$cur_theme"
  [ -n "$cur_wall" ] && last_wall="$cur_wall"
done
