# Hammerspoon Window Cycle

Upgrade native **Command + `** to switch between an app's windows across macOS desktops.
Keep Command held and tap the grave-accent key; each release switches to the next window.
Add Shift to go backward.

The focused app is detected automatically. Works with apps that expose a standard
English **Window** menu with a checked current-window entry; Chrome and Ghostty
have been manually tested.

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
keyboard event listener. In the tested Chrome password window, Secure Input
blocked the listener but allowed the registered hotkey.

The module checks the focused app's menu when you switch apps or its windows change.
Hotkeys are enabled only when a usable window list is present. Selection happens
when the grave-accent key is released. The module uses menu elements directly,
so two windows with the same title remain distinct.

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
- Cycles in Window-menu order, which can change when window titles change.
- Manually tested with three Chrome windows and two Ghostty windows across two
  desktops on macOS 27.0.1, with Stage Manager enabled. Switching from a Chrome
  window with Secure Input enabled was also tested.
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
titles, switching on key release, application changes, and missing menu
selection. They do not move real windows or prove macOS integration behavior.

## License

[MIT](LICENSE).
