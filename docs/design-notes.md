# Design notes

Lessons to carry into our own profiles. These are distilled from the vendored
**Unit-3** rice (by samyns, MIT), which was evaluated and then removed from the repo.
The profile itself is gone; the lessons are worth keeping.

## Things to avoid when building profiles

### 1. Don't make the lock screen depend on a single compositor-shell process

Unit-3 wired **only** a Quickshell-based lock screen (`SUPER+L` →
`qs -p lockscreen.qml`) and set it to run on every login. Quickshell is one userspace
process; if it fails to start, **the screen never locks** — a security gap, not just a
cosmetic one. Worse, a fully-configured `hyprlock` fallback (`hyprlock.conf` +
`hypr/lock.sh`) was shipped in the profile but never bound to anything, so the safety net
existed on disk and did nothing.

**Do instead:** always wire a shell-independent lock (e.g. `hyprlock`) as a fallback bind,
separate from any fancy compositor-shell lock. The locker is security-critical — it must
not have a single point of failure that a QML/Qt problem can take out. Treat "screen won't
lock" as a release blocker.

### 2. Don't unconditionally kill the fallback notification daemon on login

Unit-3 ran `exec-once = pkill dunst` (alongside `pkill mako` / `pkill swaync`) on every
login so Quickshell could own the `org.freedesktop.Notifications` DBus name. The effect:
if Quickshell failed, there was **no** notification daemon left at all — notifications
silently vanished with no fallback.

The nuance that makes this easy to get wrong: two daemons **cannot** both own the
notification DBus name (first to bind wins), so you can't just leave dunst running
alongside the shell — that risks breaking the shell's own notifications.

**Do instead:** clear only the daemons you're genuinely not using, and bring up the
fallback *conditionally* — start it only if the primary shell didn't come up, so it never
competes with a healthy shell but still covers its failure. The pattern we used:

```
exec-once = sleep 5 && pgrep -x qs >/dev/null || dunst
```

Any single-owner resource (notifications, tray, polkit agent, wallpaper daemon) deserves
the same treatment: don't destroy the fallback to hand the resource to something that
might not show up.

### 3. Be wary of `-git` AUR packages for load-bearing components (Qt6 ABI fragility)

Unit-3's entire UI — bar, menu, control center, notifications, lock screen, volume OSD —
runs on `quickshell-git`, an AUR **git** package built against the system Qt6. A Qt6 ABI
bump breaks a `-git` build until it is rebuilt, and it already broke once here for exactly
that reason. A `-git` package also isn't reproducible: two installs days apart can pull
different upstream commits.

**Do instead:**
- Don't put the whole desktop's critical path behind one `-git` package. Keep the essential
  surfaces (locking, notifications, a usable bar) working even if that component is down —
  which is really lessons 1 and 2 restated: **fallbacks for anything load-bearing.**
- Prefer tagged/stable releases over `-git` where they exist; if a `-git` package is
  unavoidable, pin a known-good build and treat a Qt/toolkit upgrade as an event that
  requires rebuilding and re-testing it before rollout.
- Keep the blast radius small: a toolkit ABI change should degrade one shell, not lock you
  out of your session or silence every notification.

## Meta-lesson

The through-line: **anything security-critical or single-owner needs a fallback that does
not share the failure mode of the primary.** A slick compositor shell is fine as the
primary experience; it is not fine as the *only* thing standing between the user and a
locked screen or a working notification path.
