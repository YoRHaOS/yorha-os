# Attribution — Unit-3

This profile (`profiles/unit3/`) vendors the **Unit-3** Hyprland + Quickshell + Waybar
rice by **samyns**.

- **Upstream:** https://github.com/samyns/Unit-3
- **License:** MIT (see `profiles/unit3/LICENSE`) — Copyright (c) 2026 samyns
- **Vendored from commit:** `ee647a0944614c5566dbb27892f542f71fab2d43` (2026-06-03)

The MIT license requires that the copyright notice and permission notice be included
in all copies or substantial portions of the software; `LICENSE` is preserved verbatim
in this directory to satisfy that condition.

## What was vendored

Copied from upstream into `profiles/unit3/`:

- `config/` — hypr, quickshell, waybar, kitty, bash, system/pam.d
- `scripts/` — upstream ships only a `.gitkeep` placeholder here (no scripts)
- `packages/` — `pacman.txt`, `aur.txt`, `pinned.txt`
- `LICENSE`

**Not vendored:** `assets/wallpapers/` was deliberately excluded — it contains
NieR:Automata / Hollow Knight artwork that is almost certainly copyrighted and cannot
ship in a public ISO. The character art under `config/quickshell/assets/` was excluded
for the same reason (see below). `install.sh`, `README.md`, and `VERSIONS.md` were also
left upstream (this is a config profile, not a system installer — see the install.sh
analysis below for why its behavior is out of scope here).

### ⚠️ Excluded character art inside `config/` — you must supply your own

`config/quickshell/assets/` in upstream contains likely-copyrighted NieR:Automata
character art. These files were **deliberately excluded** from this profile for the
**same reason as the wallpapers** — they cannot ship in a public repo/ISO:

| File (excluded) | Size upstream | Referenced by |
|------|------|---------|
| `2b.gif` | 1.4 MB | `config/quickshell/widgets/Companions.qml` |
| `amazon.gif` | 713 KB | `config/quickshell/widgets/Companions.qml` |
| `mai.gif` | 521 KB | `config/quickshell/widgets/Companions.qml` |
| `nier-arrow.png` | 15 KB | UI decoration |

`config/quickshell/widgets/Companions.qml` still references these paths, so the
companion widget will show **broken image references** until you drop your own
(non-infringing) assets into `config/quickshell/assets/` at the same filenames.
No placeholder stubs were added on purpose: a broken image ref is a clearer signal
that an asset is missing than a silent blank frame would be.

## (a) hyprlang `.conf` files that need Lua conversion

Hyprland deprecated hyprlang configuration at **0.55**; this project targets **0.56.2**.
The following vendored files are in hyprlang format and will need conversion to Lua via
`hyprconf2lua` (installed with `pip install hyprconf2lua`):

- `config/hypr/hyprland.conf`
- `config/hypr/hyprlock.conf`
- `config/hypr/hyprpaper.conf`

Not hyprlang (no conversion needed): `config/kitty/kitty.conf` (kitty format),
`config/waybar/config.jsonc` (JSON), `config/waybar/style.css` (CSS), all
`config/quickshell/**/*.qml` (QML). Note also that upstream's `hyprland.conf` expects a
user override at `~/.config/hypr/user.conf` (created by its installer, not vendored).

## (b) Package requirements, cross-referenced against `base/packages/explicit.txt`

Cross-referenced against `base/packages/explicit.txt` as of this branch.

### pacman (`packages/pacman.txt`)

**Already in `explicit.txt` (18):**
brightnessctl, grim, hypridle, hyprland, hyprlock, kitty, networkmanager,
noto-fonts-emoji, pavucontrol, pipewire-alsa, pipewire-pulse, polkit-kde-agent,
qt5-wayland, qt6-wayland, slurp, waybar, wl-clipboard, xdg-desktop-portal-hyprland

**NOT in `explicit.txt` — need installing (26):**
cloudflared, figlet, fish, gtk4-layer-shell, hyprshot, kdeconnect, noto-fonts,
noto-fonts-cjk, pipewire, playerctl, python-cairo, python-numpy, python-opencv,
python-pillow, python-qrcode, qrencode, qt6-multimedia-ffmpeg, satty, starship,
ttf-jetbrains-mono, udiskie, udisks2, wireplumber, xdg-user-dirs, xdg-utils, yazi

Notes:
- `pipewire` is pulled in transitively by `pipewire-alsa`/`pipewire-pulse` (already
  listed) but is not itself an explicit entry.
- `ttf-jetbrains-mono` is the plain font; `explicit.txt` has the **`-nerd`** variant
  (`ttf-jetbrains-mono-nerd`) instead — related but a different package.
- `noto-fonts` (base family) and `noto-fonts-cjk` are absent; `explicit.txt` only has
  `noto-fonts-emoji`.

### AUR (`packages/aur.txt`)

**Already in `explicit.txt` (1):** quickshell-git

**NOT in `explicit.txt` — need installing (2):**
awww (wallpaper daemon), pamtester (PAM verification for the Quickshell lockscreen)

### `packages/pinned.txt`

This is **not a manifest** — it is a maintainer shell snippet (with French comments,
`cd ~/projets/Unit-3`) that *generates* `pinned-pacman.txt`/`pinned-aur.txt` by querying
locally installed versions with `pacman -Qi`. Vendored as-is for completeness; it is not
consumed by anything in this repo.

## (c) What upstream `install.sh` does beyond copying configs

Recorded here because `install.sh` is a full-system Arch installer, **not** a config
drop-in — none of the following is performed by vendoring this profile, and any
integration into `yorha-os` must reproduce the wanted behaviors deliberately:

- **Package installation:** `sudo pacman -S --needed` for all of `pacman.txt`;
  bootstraps the **yay** AUR helper by cloning `yay-bin` from the AUR and running
  `makepkg -si`; installs `aur.txt` via yay/paru. A `--pinned` mode **downloads**
  `.pkg.tar.zst` files from `archive.archlinux.org` and installs them with `pacman -U`.
- **System PAM file:** installs `config/system/pam.d/qs-lock` to **`/etc/pam.d/qs-lock`**
  via `sudo install -D -m 644` (required for the Quickshell lockscreen's PAM auth).
- **systemd services:** `systemctl enable --now NetworkManager.service` (system) and
  `systemctl --user enable --now pipewire pipewire-pulse wireplumber` (user).
- **Symlink:** `~/.local/bin/qshare` → `config/quickshell/scripts/qshare.py`.
- **Home-dir writes:** overwrites `~/.bashrc` (with backup) and creates `~/.bashrc.local`;
  creates/preserves `~/.config/hypr/user.conf`; makes `.sh`/`.py` under the deployed
  hypr/quickshell/waybar dirs executable.
- **Wallpapers & dirs:** creates `~/Pictures/wallpapers` and `~/Screenshots`, copies the
  (excluded) bundled wallpapers into place.
- **Other:** backs up existing configs to `~/.config-backup-<timestamp>`; keeps a
  background `sudo -v` keep-alive loop; a `--vm`/`UNIT3_VM=1` mode `sed`-patches configs
  to use software OpenGL (llvmpipe) for Quickshell + Kitty; runs under `set -euo pipefail`
  and cleans up its own temp clone on exit.
