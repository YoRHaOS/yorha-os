# YoRHa OS — Visual Identity (Locked)

> **This is the locked visual identity.** Every profile and surface theme must derive
> from it. When starting a new profile or theming a new surface, read this first.

**Reference artifact:** [`branding/yorha-os-onboarding.html`](../branding/yorha-os-onboarding.html)
— this is the canonical source of truth for the look. Anyone doing surface theming should
open that file in a browser directly, not just read this summary.

## Color Palette

| Role | Hex | Notes |
|---|---|---|
| Background | `#d3cdb6` | warm sand / parchment |
| Background (deep) | `#c6bfa4` | secondary panel shade |
| Text (ink) | `#4a4739` | primary text color |
| Text (soft) | `#6b6754` | secondary/body text |
| Text (faint) | `#8d8873` | labels, eyebrows, muted UI |
| Rule/border | `#8d8873` | hairlines, dividers |
| Accent ("hot") | `#bb5b32` | rust/terracotta — buttons, highlights, active states |
| Panel | `#dcd7c3` | framed panel fill |

## Typography

- **Body/serif:** Iowan Old Style → Palatino Linotype → Palatino → Georgia (serif fallback stack)
- **Monospace:** ui-monospace → SFMono-Regular → Menlo → Consolas — used for labels, code, eyebrows, step badges, chapter markers
- Uppercase, letter-spaced (`.2–.3em`) for small labels/eyebrows
- Arabic mode: Amiri (serif) / Noto Kufi Arabic (UI labels) — full RTL support already built and tested

## Signature Details

- **Corner tick-mark framing** — thin 2px L-shaped brackets on each corner of panels, not full rounded borders
- **Scanline overlay texture** — subtle repeating horizontal gradient at low opacity (~5.5%) over the whole screen, straight out of the NieR menu aesthetic
- **Hairline rules** — 1px dividers, low opacity, never heavy borders
- **Numbered steps** — bracketed/boxed digit badges (`01`, `02`...) instead of bullet points, monospace, accent-colored
- **Framed panel with inset border** — outer 1px border + a second inset border ~7px in, creating a "double frame" look

## Where This Needs to Land in the Actual Distro

| Surface | Feasibility | Notes |
|---|---|---|
| **Plymouth (boot splash)** | High — real fonts, real images, animation | Biggest bang for the buck since it's on screen longest and systemd-boot itself can't be themed |
| **SDDM (login screen)** | High — QML supports real layout/fonts/frames | Can genuinely replicate the framed-panel + corner-tick look |
| **Hyprlock (lock screen)** | High — supports shapes/borders/images | Near 1:1 translation of the HTML's frame styling |
| **Waybar / yorha-bar** | High — CSS-based | Hand-set the palette as fixed values rather than relying on wallust's wallpaper-derived colors |
| **rEFInd (boot menu)** | Medium — static art only | Themed background/icons can evoke the vibe; no animation, no live text, no scanlines possible |
| **GTK/Qt app theming** | Low-medium | Match the palette, don't chase pixel-perfect — apps have their own widget conventions |

## Ground Rule

Nothing renders literal HTML/CSS outside a browser. Every surface above is a
**translation**, not a port — match the palette, typography direction, and structural
motifs (frames, ticks, hairlines, numbered badges) as closely as each format allows, but
expectations should scale down from "identical" to "unmistakably the same design
language."

## Theming Modes

There are **three** theming modes. They are **mutually exclusive** — exactly one is active
at a time.

1. **Light** (default) — the locked palette above, unchanged.
2. **Dark** — the same hues with the ink/sand roles inverted, using a *derived* ramp (not a
   literal table swap — see below).
3. **Wallpaper-derived** (opt-in, off by default) — [wallust](https://codeberg.org/explosion-mental/wallust)
   generates the palette from the user's current wallpaper.

### The contract: one `colors.css`, identical variable names

Every mode is expressed as a single **`colors.css`** file that defines the same eight CSS
custom properties on `:root`. Waybar and every other CSS-driven surface `@import` this one
file and never hard-code hexes:

```css
@import "colors.css";           /* whatever mode is active */
/* then use var(--sand), var(--ink), var(--hot), … everywhere */
```

The variable names are fixed across all three modes (these are exactly the names the
reference artifact already uses):

| Variable | Role |
|---|---|
| `--sand` | base background / page |
| `--sand-deep` | recessed secondary shade |
| `--panel` | framed-panel fill (lifts above the page) |
| `--ink` | primary text |
| `--ink-soft` | secondary / body text |
| `--ink-faint` | labels, eyebrows, muted UI |
| `--rule` | hairlines, dividers, borders |
| `--hot` | accent (buttons, highlights, active states, step badges) |

Because the names never change, **switching modes is swapping one file and nothing else.**
The recommended mechanism: each mode ships its own file (e.g.
`themes/light/colors.css`, `themes/dark/colors.css`, and a generated
`themes/dynamic/colors.css`), and the active one is symlinked/copied to a single canonical
path that every surface imports (e.g. `~/.config/yorha/colors.css`). No surface stylesheet
is edited when the mode changes.

### Mode 1 — Light (default)

The locked palette, verbatim:

```css
/* themes/light/colors.css */
:root{
  --sand:      #d3cdb6;   /* base background — warm sand / parchment */
  --sand-deep: #c6bfa4;   /* recessed secondary shade (darker than base) */
  --panel:     #dcd7c3;   /* framed-panel fill (lighter than base — lifts up) */
  --ink:       #4a4739;   /* primary text (darkest — most contrast on sand) */
  --ink-soft:  #6b6754;   /* body text */
  --ink-faint: #8d8873;   /* labels / muted (lightest text — least contrast) */
  --rule:      #8d8873;   /* hairlines (== faint) */
  --hot:       #bb5b32;   /* accent — rust / terracotta */
}
```

### Mode 2 — Dark (derived, not mirrored)

**Why a literal swap is wrong.** In light mode the three text tones run *dark → light*
(`--ink` #4a4739 is the darkest and most prominent; `--ink-faint` #8d8873 is the lightest
and most muted), while the three background tones sit in a narrow bright band (L≈71–84%).
If you just move the sand family into the text slots, two things break:

- **Hierarchy inverts.** The sand tones ordered by lightness are `panel` > `sand` >
  `sand-deep`. Drop them into `--ink`/`--ink-soft`/`--ink-faint` and the "muted" tone can
  end up *brighter* than the "primary" tone — the opposite of what the roles mean.
- **The ramp collapses.** The sand family only spans ~13 lightness points. As text on a
  near-black background all three tones read as nearly the same brightness, so there is no
  usable hierarchy left.

So dark mode keeps the **same hue and low saturation** (warm yellow-brown neutral, ~45–48°)
but assigns **new lightness values** chosen to preserve the *relationships* light mode has:
primary text has the most contrast against the page, faint the least; the panel still lifts
*above* the page while `sand-deep` still recedes *below* it.

```css
/* themes/dark/colors.css */
:root{
  --sand:      #23211a;   /* base background — warm near-black */
  --sand-deep: #1b1a13;   /* recessed shade (darker than base, still) */
  --panel:     #2f2c22;   /* framed-panel fill (lighter than base — still lifts up) */
  --ink:       #e4dec8;   /* primary text (brightest — most contrast on the dark page) */
  --ink-soft:  #b3ac96;   /* body text (clearly dimmer than primary) */
  --ink-faint: #8d8873;   /* labels / muted — the shared neutral pivot */
  --rule:      #57523f;   /* hairlines — dim warm line, subtle on dark */
  --hot:       #cf6b3f;   /* accent — lifted terracotta (see below) */
}
```

**Reasoning, per value:**

- **`--sand` #23211a / `--sand-deep` #1b1a13 / `--panel` #2f2c22.** The dark backgrounds are
  the ink hue pushed very dark, not pure black — keeping the palette *warm*, the way light
  mode is warm parchment rather than pure white. Crucially the internal ordering is
  preserved: `panel` (L≈17%) is the *lightest* of the three so a framed panel still lifts
  above the page (`sand`, L≈13%), and `sand-deep` (L≈10%) is the *darkest* so it still reads
  as recessed. Same spatial logic as light mode, mirrored across the lightness axis.
- **`--ink` #e4dec8.** Primary text is the *brightest* tone, a warm off-white drawn from the
  sand identity — so it carries the most contrast against the dark page, exactly as
  `--ink` #4a4739 carries the most contrast against light. (≈12:1 on `--sand`.)
- **`--ink-soft` #b3ac96.** Deliberately spaced well below primary (≈6.5:1) so body text is
  distinguishable from headings — the spacing the naive sand-family swap loses.
- **`--ink-faint` #8d8873 — reused unchanged from light mode.** This mid neutral is the
  pivot the whole system rotates around: it's the *lightest/muted* text on light backgrounds
  and the *dimmest/muted* text on dark backgrounds (≈4.6:1 on `--sand` — muted but legible).
  Keeping it identical ties the two modes together and is the one row where a "swap" is
  actually correct.
- **`--rule` #57523f.** Light mode sets `--rule` == `--ink-faint`. On dark that would be too
  bright for a hairline, so the rule instead uses the *dark* neutral — dim enough to stay a
  low-contrast divider ("never heavy borders") while still visible against `--sand`.

**The accent — use a variant, not the same hex.** `#bb5b32` is a mid-luminance saturated
rust (L≈46%). Against light sand it sits *darker* than its background, so it reads as a
grounded, anchored terracotta. Against a near-black page the identical hex sits *lighter*
than its background and the perception flips: a mid-dark saturated orange on dark tends to
look muddy, vibrates against the near-black, and — because `--hot` is also used for small
text (step badges, the `$` prompt) — `#bb5b32` only clears ≈3.3:1 on `--sand`, too low for
small type. Dark mode therefore uses **`--hot` #cf6b3f**: the *same hue* (~17°), lightness
lifted ~6 points and saturation eased slightly. That restores the perceived vividness the
dark field drains, stops the vibration, and lifts small-accent text to ≈4.8:1 on `--sand`.
It is the same accent *identity*, retuned for its background — consistent with this doc's
"translation, not a port" rule.

### Mode 3 — Wallpaper-derived (opt-in, off by default)

wallust reads the user's current wallpaper and generates a palette from it. This mode is
**off by default** and must be explicitly selected.

- **It overrides modes 1 and 2.** When dynamic mode is on, wallust writes the active
  `colors.css` (via a wallust template that emits **the same eight variable names** — see
  below), so the hand-authored light/dark files are not used while it is enabled. There is
  no blending: exactly one mode is live.
- **wallust must not run in `exec-once` unless this mode is selected.** Do **not** put
  `wallust run …` in Hyprland's `exec-once` (or any login autostart) as a default. It only
  belongs in the startup path when the user has opted into dynamic mode; otherwise it would
  silently clobber the locked light/dark palette at every login. Gate it behind the mode
  selection (e.g. an autostart line that is only present/uncommented for dynamic mode).
- **The template must honor the contract.** wallust's output template has to define the same
  `:root` variables (`--sand`, `--sand-deep`, `--panel`, `--ink`, `--ink-soft`,
  `--ink-faint`, `--rule`, `--hot`) so that Waybar and every other surface keep working with
  zero changes. Dynamic mode is responsible for mapping wallust's extracted colors onto
  these roles sensibly (a dark-enough base for `--sand`, a legible `--ink`, a saturated
  swatch for `--hot`) — the surfaces neither know nor care which mode produced the file.

### Summary

| Mode | Default | Source of `colors.css` | Notes |
|---|---|---|---|
| Light | ✅ | `themes/light/colors.css` (hand-authored) | The locked palette. |
| Dark | — | `themes/dark/colors.css` (hand-authored) | Derived ramp; accent retuned to `#cf6b3f`. |
| Wallpaper-derived | — | generated by wallust into `themes/dynamic/colors.css` | Overrides 1 & 2; wallust runs at login **only** in this mode. |

Same eight variable names in every case; switching modes swaps exactly one file.
