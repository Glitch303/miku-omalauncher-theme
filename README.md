# Miku — Dynamic Wallpaper Theme for Omalauncher

An Omalauncher theme that automatically follows your wallpaper colors.
Uses [matugen](https://github.com/hanabi1224/matugen) to extract a palette
from the active wallpaper, tinted with Miku's signature teal.

> **Disclaimer:** This is an unofficial fan project. "Hatsune Miku" is a
> trademark of Crypton Future Media, Inc. This theme uses no official
> artwork, audio, or assets — only the name and a teal color accent.
> Not endorsed by or affiliated with Crypton Future Media, Inc. or Sega.

> **P.S.** Works with any wallpaper — Miku's or otherwise. The colors
> always follow whatever image you set as your background.

## Files

| File | Purpose |
|------|---------|
| `recolor.sh` | Regenerates colors and triggers the launcher to re-read them (Omalauncher) |
| `recolor-omarchy.sh` | Regenerates colors for plain Omarchy (Linux) — no launcher needed |
| `recolor.py` | Color extraction logic (matugen → Miku-tinted palette) |
| `watch.sh` | Background watcher that runs `recolor.sh` automatically when the wallpaper changes |
| `icons.theme` | Icon theme reference |

## Install

Copy this directory into your Omalauncher themes folder:

```
cp -r miku ~/.local/share/omarchy/themes/
```

Then select **Miku** in the launcher's Style menu.

## Usage

### Automatic (watcher)

Start the watcher (survives wallpaper changes, dies on reboot):

```
nohup ~/.local/share/omarchy/themes/miku/watch.sh &>/dev/null &
```

Stop it:

```
pkill -f "miku.*watch.sh"
```

Log:

```
cat ~/.local/state/omalauncher/miku-watch.log
```

### Manual (Omalauncher)

Run after changing your wallpaper:

```
~/.local/share/omarchy/themes/miku/recolor.sh
```

### Omarchy (Linux, no launcher)

For a plain Omarchy setup (Hyprland + foot + btop), use the Omarchy
script instead. It writes to `~/.local/state/omarchy/current/theme/`
and live-recolors running terminals — no theme cycling, no restart:

```
~/.local/share/omarchy/themes/miku/recolor-omarchy.sh
```

What it does:
1. Extracts colors from the wallpaper (matugen)
2. Writes `colors.toml` and `foot.ini` to `current/theme/`
   (where foot, btop, and other apps already read from)
3. Sends OSC sequences to all running foot terminals for instant recolor
4. Sends SIGUSR2 to btop to reload its theme

Does **not** modify the theme directory — only the runtime `current/theme/`
copy. Your `colors.toml` in the theme dir stays as-is.

## How It Works

### Color extraction (both scripts)

1. `matugen` extracts a color palette from the wallpaper
2. `recolor.py` generates `colors.toml` — wallpaper colors blended with
   Miku's teal (`hue 185`) for the accent

### Omalauncher (`recolor.sh`)

3. Writes `colors.toml` to the theme directory
4. Cycles `style.toml` (`miku → miku-<timestamp> → miku`) to force the
   launcher's `FileObserver` to re-read `colors.toml` via `followStyle()`
5. The launcher's in-memory `Palette` updates and the UI recolors

The intermediate theme name (`miku-<timestamp>`) doesn't exist, so the
launcher never applies it — no visible flash.

### Omarchy (`recolor-omarchy.sh`)

3. Writes `colors.toml` and `foot.ini` to `current/theme/`
4. Sends OSC color sequences to running foot terminals
5. Sends SIGUSR2 to btop

No theme cycling needed — Omarchy apps read directly from `current/theme/`.

## Requirements

- Omalauncher
- [matugen](https://github.com/hanabi1224/matugen)
- Python 3
