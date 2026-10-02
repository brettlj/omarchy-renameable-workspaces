# Renameable Workspaces

An Omarchy bar widget that shows Hyprland workspace numbers — just like the
built-in workspaces widget — but lets you give any workspace a custom name.

## Features

- Right-click a workspace number to rename it.
- The name replaces the number on the bar and sticks until you change or
  reset it — it survives shell restarts and `omarchy update`.
- The currently focused workspace is highlighted with an accent-colored pill
  instead of hiding the name/number behind an icon.
- Left-click still switches workspaces, exactly like the stock widget.

## Installation

```
omarchy plugin add https://github.com/bagayasbryan-code/omarchy-renameable-workspaces --enable
```

This installs and enables the widget, adding it to the bar alongside
whatever's already there. To have it take the place of the built-in
workspaces widget instead of sitting next to it, edit
`~/.config/omarchy/shell.json` and change that entry's

```json
"id": "omarchy.workspaces"
```

to

```json
"id": "bpbagayas.renameable-workspaces"
```

`shell.json` hot-reloads on save, so the bar updates immediately.

## Usage

- **Left-click** a workspace number: focus that workspace.
- **Right-click** a workspace number: open a small popup with a text field.
  - Type a name and press **Enter** or click **Save** to rename it.
  - Click **Reset** (or save an empty field) to go back to the plain number.
  - Press **Escape** or click outside the popup to cancel without changes.
  - **Show workspace number** (on by default) prefixes that workspace's name
    with its number (`4 Dev`). The number is dimmed and sits closer to its name
    than to the next workspace. Each workspace has its own setting; it is
    applied on **Save**, and **Reset** turns it back on.

Names are stored in `~/.local/state/omarchy/settings/workspace-names.json`,
keyed by workspace number.

## Settings

Settings live on the widget's entry in `~/.config/omarchy/shell.json` and
hot-reload on save:

```json
{
  "id": "bpbagayas.renameable-workspaces",
  "hiddenNumbers": [3, 6],
  "numberOpacity": 0.5
}
```

- `hiddenNumbers` (default `[]`): workspaces whose number is hidden; set by
  the popup checkbox.
- `numberOpacity` (default `0.5`): opacity of the number prefix, `0`-`1`.

## Removal

```
omarchy plugin remove bpbagayas.renameable-workspaces
```

If it's currently enabled, removing it restores the built-in
`omarchy.workspaces` widget in its place.

## License

MIT — see [LICENSE](LICENSE).
