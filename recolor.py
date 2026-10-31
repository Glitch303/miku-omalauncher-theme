import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)
out = sys.argv[2]
mode = 'dark' if data['is_dark_mode'] else 'light'
c = data['colors']

def g(k):
    v = c.get(k)
    if isinstance(v, dict):
        for m in (mode, 'default', 'light', 'dark'):
            if m in v and isinstance(v[m], dict) and 'color' in v[m]:
                return v[m]['color']
    return '#000000'

def hex2rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

def rgb2hex(c):
    return '#%02X%02X%02X' % c

def rgb2hsl(c):
    r, g, b = c[0]/255, c[1]/255, c[2]/255
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2
    if mx == mn:
        return 0, 0, l
    d = mx - mn
    s = d / (2 - mx - mn) if l > 0.5 else d / (mx + mn)
    if mx == r:
        h = ((g - b) / d) % 6
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return (h / 6) * 360, s, l

def hsl2rgb(h, s, l):
    h /= 360
    if s == 0:
        v = int(l * 255)
        return (v, v, v)
    def hue2rgb(p, q, t):
        if t < 0: t += 1
        if t > 1: t -= 1
        if t < 1/6: return p + (q - p) * 6 * t
        if t < 1/2: return q
        if t < 2/3: return p + (q - p) * (2/3 - t) * 6
        return p
    q = l * (1 + s) if l < 0.5 else l + s - l * s
    p = 2 * l - q
    return (int(hue2rgb(p, q, h + 1/3) * 255),
            int(hue2rgb(p, q, h) * 255),
            int(hue2rgb(p, q, h - 1/3) * 255))

def make(h, s, l):
    return rgb2hex(hsl2rgb(h, s, l))

# Extract base colors from wallpaper
bg_hex = g('background')
fg_hex = g('on_background')
prim_hex = g('primary')

bg_r = hex2rgb(bg_hex)
fg_r = hex2rgb(fg_hex)
prim_r = hex2rgb(prim_hex)

# Get the primary's hue for the accent
prim_h, prim_s, prim_l = rgb2hsl(prim_r)

# Accent: use the wallpaper's primary hue, biased slightly toward
# Miku's teal (hue 185) so it still feels "Miku" on any wallpaper.
# 70% wallpaper hue + 30% teal hue (circular blend).
MIKU_TEAL_HUE = 185
def hue_blend(h1, h2, w2):
    """Blend two hues circularly: w2 weight on h2."""
    diff = ((h2 - h1 + 540) % 360) - 180  # shortest signed distance
    return (h1 + diff * w2) % 360

accent_h = hue_blend(prim_h, MIKU_TEAL_HUE, 0.3)
accent_s = max(prim_s, 0.4)
if mode == 'dark':
    accent_l = 0.65
else:
    accent_l = 0.40
accent = make(accent_h, accent_s, accent_l)

# Selection: slightly lighter/darker than background
if mode == 'dark':
    selection = make(prim_h, 0.15, 0.18)
else:
    selection = make(prim_h, 0.15, 0.88)

# Muted: between background and foreground
muted_r = tuple(int(b * 0.4 + f * 0.6) for b, f in zip(bg_r, fg_r))
muted = rgb2hex(muted_r)

# Backgrounds
dark_bg = rgb2hex(tuple(max(0, int(c * 0.85)) for c in bg_r))
darker_bg = rgb2hex(tuple(max(0, int(c * 0.72)) for c in bg_r))
light_bg = rgb2hex(tuple(min(255, int(c * 1.08)) for c in bg_r))

# Foregrounds
dark_fg = rgb2hex(tuple(int(c * 0.6) for c in fg_r))
light_fg = rgb2hex(tuple(min(255, int(c * 1.15)) for c in fg_r))
bright_fg = rgb2hex(tuple(max(0, int(c * 0.45)) for c in fg_r))

# Terminal colors: use fixed hues with proper saturation/lightness
# These follow the pattern from tokyo-night / nord themes
if mode == 'dark':
    # Dark mode: medium brightness, good saturation
    tl = 0.65  # base lightness
    ts = 0.55  # base saturation
    bright_l = 0.72
    bright_s = 0.60
else:
    # Light mode: darker colors for contrast on light background
    tl = 0.38
    ts = 0.50
    bright_l = 0.30
    bright_s = 0.55

# Fixed hues for terminal colors (matching Omarchy conventions)
term_hues = {
    'red': 350,
    'orange': 20,
    'yellow': 45,
    'green': 130,
    'cyan': 190,
    'blue': 220,
    'magenta': 280,
    'brown': 15,
}

term = {}
bright = {}
for name, h in term_hues.items():
    s = ts
    l = tl
    # Red gets a bit more saturation
    if name == 'red':
        s = ts + 0.1
    term[name] = make(h, s, l)
    bright[name] = make(h, bright_s, bright_l)

# Brown is less saturated
term['brown'] = make(15, 0.35, tl - 0.05)
bright['brown'] = make(15, 0.45, bright_l)

lines = [
    '# Miku theme: colors follow the active wallpaper (matugen).',
    '',
    'mode = "%s"' % mode,
    '',
    'accent = "%s"' % accent,
    'selection = "%s"' % selection,
    'muted = "%s"' % muted,
    '',
    'background = "%s"' % bg_hex,
    'dark_background = "%s"' % dark_bg,
    'darker_background = "%s"' % darker_bg,
    'lighter_background = "%s"' % light_bg,
    '',
    'foreground = "%s"' % fg_hex,
    'dark_foreground = "%s"' % dark_fg,
    'light_foreground = "%s"' % light_fg,
    'bright_foreground = "%s"' % bright_fg,
    '',
    'red = "%s"' % term['red'],
    'yellow = "%s"' % term['yellow'],
    'orange = "%s"' % term['orange'],
    'green = "%s"' % term['green'],
    'cyan = "%s"' % term['cyan'],
    'blue = "%s"' % term['blue'],
    'magenta = "%s"' % term['magenta'],
    'brown = "%s"' % term['brown'],
    '',
    'bright_red = "%s"' % bright['red'],
    'bright_yellow = "%s"' % bright['yellow'],
    'bright_green = "%s"' % bright['green'],
    'bright_cyan = "%s"' % bright['cyan'],
    'bright_blue = "%s"' % bright['blue'],
    'bright_magenta = "%s"' % bright['magenta'],
]
open(out, 'w').write('\n'.join(lines) + '\n')
print('colors: mode=%s accent=%s bg=%s' % (mode, accent, bg_hex))
