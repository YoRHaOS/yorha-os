# YoRHa OS

> **Starting a new profile or theming a surface?** Read
> [`docs/visual-identity.md`](docs/visual-identity.md) first — it is the **locked**
> visual identity, and every profile and surface theme must derive from it.

A NieR-flavored Arch-based distribution: base system, Hyprland profiles, and surface
theming (Plymouth, SDDM, hyprlock, Waybar, rEFInd) unified under one visual identity.

## Repository layout

- `base/` — base system package lists and setup
- `profiles/` — desktop profiles (e.g. `profiles/hyprland/`)
- `themes/` — theme palettes as `colors.css` files (`themes/light/`, `themes/dark/`)
- `scripts/` — helper scripts (e.g. `scripts/set-theme.sh`)
- `docs/` — design and identity documentation
  - [`docs/visual-identity.md`](docs/visual-identity.md) — locked visual identity spec
  - [`docs/design-notes.md`](docs/design-notes.md) — lessons to avoid when building profiles

## Theming

The visual identity supports three mutually-exclusive modes (see
[`docs/visual-identity.md`](docs/visual-identity.md#theming-modes)). Each is a single
`colors.css` exposing the same eight CSS variables, so surfaces `@import` one file and
switching modes swaps only that file.

Switch between the two hand-authored modes with:

```sh
scripts/set-theme.sh light   # default locked palette
scripts/set-theme.sh dark    # derived dark ramp
```

The script copies the chosen `themes/<mode>/colors.css` to the canonical path every
surface imports — `~/.config/yorha/colors.css` by default (override with the
`YORHA_COLORS` environment variable). Surfaces should import that path, e.g.:

```css
@import "/home/you/.config/yorha/colors.css";
/* then use var(--sand), var(--ink), var(--hot), … */
```

The third mode (wallpaper-derived, via wallust) is opt-in and off by default; wallust
writes the canonical file itself when enabled, so it is not handled by this script.
