# DBF-MCM

A reusable Helldivers 2 mod configuration framework inspired by Skyrim/SkyUI and Fallout 4 MCM. Register a Lua definition once; DBF-MCM supplies the menu, persistent settings, input handling and controls. This is an independent implementation.

## Features

- One expandable mod/category/page tree with nested categories.
- Toggles, draggable sliders with numeric entry, choice arrows and scrollable dropdowns tested with 100 choices, key binding values, buttons, text and sections.
- RGB/HEX color picker, spectrum, brightness and persistent custom swatches.
- Immediate saving by default; optional per-page confirmation with Apply/Discard.
- Draggable windows, Close buttons, mouse-wheel scrolling and position scrollbars.
- Bingus Mod Options Menu compatibility adapter using original saved values/callbacks.

## Install and use

Requires Windows x64, MDL API 2, and the game's Stingray Lua environment. Copy the built `dbf_mcm` directory to `%LOCALAPPDATA%/MDL/Helldivers2/Mods/`, refresh MDL and enable DBF-MCM. Press **F10**. The installed display name is currently **Mod Configuration Menu (Preview)**.

Keep Bingus Mod Options Menu enabled for its imported registrations. No separate HUD assets or private developer payloads are bundled. Do not copy framework internals into each consuming mod.

## Mod author quick start

```lua
local api = rawget(_G, 'DBFMCM')
if api and api.api == 1 then
    local handle = api.register({
        id = 'author_my_mod', name = 'My Mod',
        pages = {{ id = 'general', name = 'General', controls = {
            { id = 'enabled', type = 'toggle', label = 'Enabled', default = true,
              on_change = function(value) print('Enabled: '..tostring(value)) end }
        }}}
    })
    -- Initialize the feature from committed settings; registration fires no callbacks.
    local enabled = handle.get('enabled')
    -- Unregister on disable, and re-register if the API instance changes.
end
```

Use the complete lifecycle in [minimal example](examples/example.lua), then [advanced example](examples/advanced.lua). Read [integration](docs/INTEGRATION.md), [API](docs/API.md), [architecture](docs/ARCHITECTURE.md) and [input capture](docs/INPUT-CAPTURE.md).

## Build and test

Python 3 and Visual Studio 2022 x64 C++ tools are required.

```powershell
python native/build.py
python build.py
python tests/run.py
# Optional local installation, preserving saved settings:
python build.py --install
```

`DBFMCM_VCVARS` can point to another installation's `vcvars64.bat`. `DBFMCM_LUA_DLL` can point to a compatible x64 LuaJIT/Lua 5.1 DLL; the test runner defaults to the usual Steam game location. ZIP output is `dist/DBF-MCM-<VERSION>.zip`. Build products, installed settings and test scratch files are ignored by Git.

## Status and boundaries

Development preview, API 1. Current tests cover registry, persistence, callbacks, input lifecycle and menu interactions; offline tests do not prove native rendering or every live input path. Visual behavior is being refined through live checks. Input capture covers window keyboard/mouse routing, not controller or direct-device polling. The menu does not pause the simulation. Native shortcut integration is disabled after a game-navigation collision; F10 is the opener.

Missing: controller navigation, localization, JSON definitions, native pause-menu entry, slider text caret/paste support, alpha colors and universal legacy adapters. Legacy registration discovery depends on the installed menu's named Lua registry and is version-sensitive. Confirmation saves are atomic at the settings-file level; gameplay callbacks/actions cannot be rolled back by the framework.

See [MCM references](docs/MCM-REFERENCE.md) for the research and scope. No third-party native menu implementation is bundled.
