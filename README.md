# Meu Trello Local

A small, local-first, Trello-like kanban board for the Linux desktop, built
with Flutter. It lives in the system tray: one click on the tray icon brings
the board up, minimizing or closing the window tucks it back into the tray.

Everything stays on your machine, in a single JSON file.

## Features

- **Task queues**: create, rename, reorder and delete lists.
- **Cards**: add cards quickly with an inline composer (Enter adds and keeps
  the field open), and edit their title and description in a dialog.
- **Drag and drop**
  - move cards within a list or across lists; an accent line shows exactly
    where the card lands
  - drop a card on a list header to put it at the top, or on empty space to
    put it at the bottom
  - drag a list by its header to reorder the board
  - the board and long lists auto-scroll when you drag near their edges
- **System tray**
  - single click on the icon: show the window, or hide it when it is
    already in front
  - right click: menu with show/hide and *Sair* (quit)
  - minimizing or closing the window hides it into the tray
- **Single instance**: launching the app again just brings the running
  window forward.
- **Start on login**: optional autostart that starts hidden in the tray.
- Follows the system light/dark theme.

### Keyboard shortcuts

| Shortcut | Action                        |
| -------- | ----------------------------- |
| `Enter`  | Add the typed card/list       |
| `Esc`    | Close the inline composer     |
| `Ctrl+W` | Hide the window into the tray |
| `Ctrl+Q` | Quit                          |

## Requirements

- Flutter 3.32+ (Dart 3.8+)
- The Flutter Linux toolchain. On Ubuntu/Debian:

  ```sh
  sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
  ```

- A desktop with a StatusNotifierItem tray host: KDE Plasma works out of the
  box; on GNOME install the *AppIndicator and KStatusNotifierItem Support*
  extension. Without a tray host the app still works, but minimize and close
  behave as usual instead of hiding the window.

No libappindicator is needed: the tray icon speaks the D-Bus protocol
directly (see [Architecture](#architecture)).

## Running

```sh
flutter pub get
flutter run -d linux
```

### Installing for your user

```sh
scripts/install.sh              # build, install and add to the app menu
scripts/install.sh --autostart  # ...and start hidden in the tray on login
```

The app is installed to `~/.local/opt/meu_trello_local`, with a
`meu-trello-local` launcher in `~/.local/bin`. To remove it:

```sh
scripts/uninstall.sh            # keeps your board
scripts/uninstall.sh --purge    # also deletes your board
```

Pass `--hidden` to the executable to start straight into the tray.

## Data

The board is saved to
`~/.local/share/io.github.professorbossini.meu_trello_local/board.json`.
Writes are debounced and atomic (written to a temporary file, then renamed),
and a file that cannot be read is kept aside as `board.json.corrupt-<time>`
instead of being overwritten.

## Architecture

```
lib/
├── main.dart                  bootstrap: single instance, storage, shell
└── src/
    ├── app.dart               MaterialApp, theme, global shortcuts
    ├── board/                 domain and state, no Flutter widgets
    │   ├── models.dart        immutable Board/TaskList/TaskCard + operations
    │   ├── board_repository.dart  JSON file persistence
    │   └── board_controller.dart  ChangeNotifier, debounced saving
    ├── ui/                    widgets
    │   ├── board_page.dart    board layout
    │   ├── list_column.dart   list column, draggable cards and drop targets
    │   ├── drag_and_drop.dart drag payloads, drop indicator, auto-scroll
    │   └── ...
    └── desktop/               Linux desktop integration
        ├── desktop_shell.dart window <-> tray behavior
        ├── single_instance.dart
        └── tray/
            ├── status_notifier_item.dart  tray icon over D-Bus
            ├── dbus_menu.dart             context menu over D-Bus
            └── app_icon.dart              procedurally drawn icon
```

**Why a hand-written tray?** Flutter tray plugins for Linux are built on
libappindicator, which only ever opens a menu when the icon is clicked. To
get a real single-click action, the app implements the
[StatusNotifierItem](https://www.freedesktop.org/wiki/Specifications/StatusNotifierItem/)
and `com.canonical.dbusmenu` protocols directly with the pure-Dart
[`dbus`](https://pub.dev/packages/dbus) package. It also registers again if
the tray host restarts.

**Icon.** The icon is drawn in code (`app_icon.dart`), which feeds the tray
pixmaps directly. The PNGs used by the window and the desktop entry are
generated from it:

```sh
dart run tool/generate_icons.dart
```

## Development

```sh
flutter analyze
flutter test
```

The tests cover the board operations, persistence, the main UI flows, real
mouse drag-and-drop gestures, and the tray and single-instance D-Bus
protocols against an in-process D-Bus server.

Commits follow [Conventional Commits](https://www.conventionalcommits.org/).
