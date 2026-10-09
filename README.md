![DBF-MCM](assets/branding/banner.png)

# DBF-MCM

**Diver's Best Friend — Mod Configuration Menu**, preview **0.1.53**.
A shared in-game settings menu for Helldivers 2 mods.

[Download](https://github.com/HWG90/DBF-MCM/releases/tag/mcm-v0.1.53-preview.1) | [Installation](docs/INSTALL-STANDALONE.md) | [Mod author quick start](docs/AUTHOR-GUIDE.md) | [API](docs/API.md) | [Credits](docs/CREDITS.md)

## UI polish pass

Clearer page headings, quieter panels and borders, more space between settings, distinct hover/focus/enabled colors, readable key names and better Apply feedback. Enter opens dropdowns, scrollbars can be dragged, and long labels scroll only while hovered or focused. Hovering never changes a setting.

**Settings** sits beside Mod Configuration. It contains the rebindable Open/Close shortcut, preferred window width/height, UI scale, font size, Reset Window and **GitHub Page**, which opens this repository in your browser after releasing menu input.

**DEL** is the default Open/Close key. Escape cancels the active editor or closes MCM. Use the mouse/wheel, or Tab, arrows and Enter. Page Up/Down changes pages. Apply, Discard and Reset Setting use buttons; no F2/F8/F9/Home action shortcuts are assigned by MCM. The menu does not pause gameplay.

## Installation

Choose one package and one MCM instance.

| Package | Loading route |
| --- | --- |
| `ModConfigurationMenu-Preview-0.1.53.zip` | **MDL API 2 or LLL**. Extract the complete `dbf_mcm` folder into the selected loader's Mods directory. |
| `DBF-MCM-Standalone-0.1.53.zip` | **Bingus Shared Loader v15+ / API 1**. Import into Arsenal, enable alongside Shared Loader, deploy and restart. |

LLL uses the same loose package as MDL; it does not need a separate download or MDL installed. Keep `mod.lua`, `library.txt` and the named DLL together. Disable the previous MCM provider before switching. Bingus Mod Options Menu is optional. Native DLL updates require a restart.

Settings retain `%LOCALAPPDATA%/MDL/Helldivers2/Mods/dbf_mcm/settings`, including when MDL is absent. Mods can supply their own storage provider. Existing IDs, linked settings and HUD preview pop-outs are preserved.

## For mod authors

Start with the [short working example](docs/AUTHOR-GUIDE.md). API 1 supports toggles, sliders, choices, keybinds, text input, colors, actions, sections, pages and categories. Stable IDs identify saved values. Callbacks run after successful persistence; failed saves leave values unchanged.

Source is organized into registration/storage, preferences, controller, input, rendering, text layout, styling, compatibility and platform actions. Builds combine these modules into the existing single-file runtime. See [architecture](docs/ARCHITECTURE.md).

## Validation and limits

Offline contracts, native policy checks, package compilation and integrity checks pass. Exact startup, fonts, cursor behavior and appearance still need live verification for each route. See [release notes](docs/RELEASE-0.1.53.md).

HUD+ 0.2.2 retains its own native Options UI; it exposes no supported MCM settings bridge in the supplied package. The native Escape-menu entry remains unfinished. Controller navigation is not provided, and intermittent dropdown text loss remains a live investigation.
