# Miku — Dynamic Wallpaper Theme for Omalauncher

An Omalauncher theme that automatically follows your wallpaper colors.
Uses [matugen](https://github.com/hanabi1224/matugen) to extract a palette
from the active wallpaper, tinted with Miku's signature teal.

> **Disclaimer:** This is an unofficial fan project. "Hatsune Miku" is a
> trademark of Crypton Future Media, Inc. This theme uses no official
> artwork, audio, or assets — only the name and a teal color accent.
> Not endorsed by or affiliated with Crypton Future Media, Inc. or Sega.

## Files

| File | Purpose |
|------|---------|
| `recolor.sh` | Regenerates colors from the current wallpaper and triggers the launcher to re-read them |
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

### Manual

Run after changing your wallpaper:

```
~/.local/share/omarchy/themes/miku/recolor.sh
```

## How It Works

1. `matugen` extracts a color palette from the wallpaper
2. `recolor.py` generates `colors.toml` — wallpaper colors blended with
   Miku's teal (`hue 185`) for the accent
3. `recolor.sh` writes the file, then cycles `style.toml`
   (`miku → miku-<timestamp> → miku`) to force the launcher's
   `FileObserver` to re-read `colors.toml` via `followStyle()`
4. The launcher's in-memory `Palette` updates and the UI recolors

The intermediate theme name (`miku-<timestamp>`) doesn't exist, so the
launcher never applies it — no visible flash.

## Requirements

- Omalauncher
- [matugen](https://github.com/hanabi1224/matugen)
- Python 3
