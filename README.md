# Hammerspoon Window Cycle

Upgrade native **Command + `** to switch between an app's windows across macOS desktops.
Keep Command held and tap the grave-accent key; each release switches to the next window.
Each hold visits the current desktop's windows first, then windows elsewhere.
Release Command to reset the sequence. Hold Shift from the first tap for reverse order;
changing direction starts a new sequence.

For example, with A and B on this desktop and C elsewhere, starting from A gives
**A → B → C → A**. Release Command while on B and the next hold gives **B → A → C → B**.

The focused app is detected automatically. Works with apps that expose a standard
English **Window** menu with a checked current-window entry.

This is a small [Hammerspoon](https://www.hammerspoon.org/) configuration module,
not a standalone app. Apps without a usable Window menu keep their native shortcut.

## Install

1. Install Hammerspoon and grant it Accessibility access when prompted.
2. Download `window_cycle.lua` from this repository and put it in `~/.hammerspoon/`.
3. Add this line to your existing `~/.hammerspoon/init.lua`:

   ```lua
   appWindowCycle = require("window_cycle")
   ```

4. Choose **Reload Config** from Hammerspoon's menu.

To undo the installation, remove that line and reload the config. You can then
delete `window_cycle.lua`. To run at login, enable Hammerspoon's launch-at-login
preference.

## How it works

The module selects entries in the application's native **Window** menu, which
includes windows on other desktops. It uses registered hotkeys rather than a
keyboard event listener. In the tested password window, Secure Input
blocked the listener but allowed the registered hotkey.

The module checks the focused app's menu when you switch apps or its windows change.
Hotkeys are enabled only when a usable window list is present. Selection happens
when the grave-accent key is released. The module uses menu elements directly,
so two windows with the same title remain distinct.

At the start of each sequence, it queries the app's standard, non-minimized windows
on the current desktop. It focuses those windows first and learns their corresponding
checked menu entries as they are visited. Remaining menu entries follow afterward.
A modifier-only listener resets the sequence when Command is released; keypresses
still use registered hotkeys.

## Privacy and permissions

The module reads application and Window-menu accessibility information,
including window titles, to select a window. It does not log or transmit that
information, capture screenshots, record audio, or make network requests.
It does not disable Secure Input or System Integrity Protection.

Accessibility access is required. Screen Recording permission is not needed by
this module. Other modules in your Hammerspoon configuration may have their own
permission requirements.

## Support and limits

- Detects compatible apps dynamically; there is no app allowlist.
- Requires an English **Window** menu whose final section lists windows and marks
  the current window with a checkmark. Apps with custom menus may not qualify.
- Local windows follow window-ID order, starting from the focused window. Windows
  elsewhere follow Window-menu order. Minimized windows are not prioritized as local.
- Manually tested with five windows from two apps across two desktops on macOS
  27.0.1, with Stage Manager enabled. Switching from a window with Secure Input
  enabled was also tested.
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
```

The tests mock Hammerspoon and check forward/reverse wraparound, duplicate
titles, local-first ordering, Command-release reset, switching on key release,
application changes, and missing menu selection. They do not move real windows
or prove macOS integration behavior.

## License

[MIT](LICENSE).
