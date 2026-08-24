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
