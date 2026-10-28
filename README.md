# Hammerspoon Window Cycle

Upgrade native **Command + `** to switch between an app's windows across macOS desktops.
Hold Command and tap the grave-accent key to browse a row of app icons and window
titles. The highlighted window is a preview: your real windows stay in place until
you release Command. Add Shift to move the highlight backward, or press Escape
while holding Command to cancel.

Identified windows on the current desktop come first, followed by other windows.
Each Command hold starts a fresh sequence from the currently focused window.
For example, with A and B on this desktop and C elsewhere, the previews are
**A → B → C → A**. Release Command with B selected to switch to B; your next hold
starts **B → A → C → B**.

The focused app is detected automatically. Works with apps that expose a standard
English **Window** menu with a checked current-window entry.

This is a small [Hammerspoon](https://www.hammerspoon.org/) configuration module,
not a standalone app. Apps without a usable Window menu keep their native shortcut.

## Install

1. Install Hammerspoon and grant it Accessibility access when prompted.
2. Download `window_cycle.lua`, `window_cycle_overlay.lua`, and
   `window_cycle_profiles.lua` from this repository and put them in `~/.hammerspoon/`.
3. Add this line to your existing `~/.hammerspoon/init.lua`:

   ```lua
   appWindowCycle = require("window_cycle")
   ```

4. Choose **Reload Config** from Hammerspoon's menu.

To undo the installation, remove that line and reload the config. You can then
delete those three module files. To run at login, enable Hammerspoon's
launch-at-login preference.

## Multiple Chrome profiles

Profile pictures are discovered automatically from Chrome's local profile metadata.
No extra configuration file is needed.

1. For each profile, use Chrome's **Window → Name Window** command and give the
   window its exact profile display name, such as `Sam` or `Sam (Work)`.
   The name must match the profile label in the full Accessibility window title.
2. Allow Hammerspoon to access Chrome's data when macOS asks. This is needed to
   read the locally stored profile pictures; Screen Recording is not required.
3. Name new windows the same way. Window naming is manual, not a global toggle.
   Multiple windows of the same profile can share its name. If you rename a
   profile, update its window names too.

These names let the switcher match profiles on other desktops without focusing
those windows first. Without a name, it can use a full Accessibility window title
when available. Unknown, duplicate, or conflicting profile matches keep the normal
app icon. Missing or unreadable pictures also fall back to the app icon.

Discovery supports the standard Chrome user-data directory. It reads `Local State`
and the account pictures referenced there once per preview. Built-in avatar artwork,
custom user-data directories, and other browsers are not supported for profile
badges. Window switching still works in other compatible apps.

Profile metadata and pictures stay on your Mac: the module does not copy them into
this repository, save generated mappings, log them, or send them anywhere.

## How it works

The module selects entries in the application's native **Window** menu, which
includes windows on other desktops. It uses registered hotkeys rather than a
keyboard event listener. In the tested password window, Secure Input
blocked the listener but allowed the registered hotkey.

The module checks the focused app's menu when you switch apps or its windows change.
Hotkeys are enabled only when a usable window list is present. If a previously
supported app's menu becomes temporarily unavailable, it retries once per second
while that app remains focused. Recovery does not require switching apps or another
window event. The retry stops when the menu returns or an unsupported app is focused.
The overlay is drawn
by Hammerspoon; it resembles the macOS app switcher but selects windows within the
focused app. It uses app icons and titles, with no window thumbnails.

The module remembers which menu entry belongs to each focused window. For windows
not yet visited, it uses unique title-prefix matches against the app's windows on
the current desktop. Duplicate or truncated titles that cannot be matched reliably
retain menu order and receive no inferred profile badge. Cached matches are
revalidated against current titles because apps can reuse menu rows. Menu entries
remain distinct even with identical titles. This avoids briefly focusing windows
just to build the preview list.

Releasing Command selects the highlighted menu entry once. Escape, changing apps,
or clicking another window cancels the preview. A modifier-only event listener
commits when a left or right Command event reports that Command is no longer held.
It uses the event's flags, not background polling, which can report stale modifier
state. Keypresses use registered hotkeys. The target is resolved from a fresh
Window menu on release.

## Privacy and permissions

The module reads application and Window-menu accessibility information,
including window titles, to select a window. It does not log or transmit that
information, capture screenshots, record audio, or make network requests.
It does not disable Secure Input or System Integrity Protection.
Profile badges read Chrome’s local profile metadata and account pictures. Profile
names and pictures are displayed locally in the switcher and are never included
in repository files or sent anywhere by the module.

Accessibility access is required for switching. Optional avatar paths in a
protected browser data folder can also require permission to access that
browser's data. Screen Recording permission is not needed by this module.
Other modules in your Hammerspoon configuration may have their own permission
requirements.

## Support and limits

- Detects compatible apps dynamically; there is no app allowlist.
- Requires an English **Window** menu whose final section lists windows and marks
  the current window with a checkmark. Apps with custom menus may not qualify.
- Identified local windows follow window-ID order, starting from the focused window.
  Other or unidentified windows follow Window-menu order. Minimized windows are not
  prioritized as local. Desktop ordering is best-effort for unvisited windows with
  ambiguous or truncated titles.
- The underlying menu selection was manually tested with five windows from two
  apps across two desktops on macOS 27.0.1, with Stage Manager enabled, including a
  window with Secure Input enabled. The preview interface has rendered successfully;
  manual end-to-end verification of the new interface is pending.
- Full-screen windows, multiple displays, other keyboard layouts, and behavior
  after reboot have not been verified.
- Depends on the apps' Window-menu structure and current-window checkmark.
  Menu changes may require an update. Without a checkmark, native shortcuts remain
  active. If the menu becomes unavailable during a keypress, an alert is shown.
- Another shortcut utility using the same keys may conflict.

## Tests

With Lua 5.3 or newer installed, run from this repository's root:

```sh
nice -n 10 lua tests/window_cycle.lua
nice -n 10 lua tests/window_cycle_overlay.lua
nice -n 10 lua tests/window_cycle_profiles.lua
```

The tests mock Hammerspoon and check preview-only navigation, commit on Command
release, cancellation, desktop ordering, ambiguous titles, application changes,
overlay layout, automatic profile discovery, permission failures, and profile matching. They do not
move real windows or prove macOS integration behavior.

## License

[MIT](LICENSE).
