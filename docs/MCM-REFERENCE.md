# MCM research and intended structure

Primary references consulted:

- [SkyUI MCM Advanced Features](https://github.com/schlangster/skyui/wiki/MCM-Advanced-Features): per-mod pages shown below the mod name, page lifecycle, disabled option flags, localization and key conflicts.
- [SkyUI MCM API Reference](https://github.com/schlangster/skyui/wiki/MCM-API-Reference): control-specific events, defaults and setting dialogs.
- [Fallout 4 MCM Menu Layout](https://github.com/Neanka/MCM_0.1_AS3/wiki/Menu-Layout): mod identity and display name, JSON definitions, named subpages and requirements.
- [MCM Helper](https://github.com/Exit-9B/MCM-Helper): author framework inspired by Fallout 4 MCM.

These are references, not copied implementation or assets. This project does not use Papyrus, SKSE, F4SE, or Bethesda Scaleform code. No third-party source from the installed Mod Options Menu is bundled.

## Target user flow

1. Open Mod Configuration from the pause menu.
2. Browse a scrolling list of registered mods on the left.
3. Expand/select the mod's subpages in that same navigation area.
4. Edit labeled controls in the right content area, with optional columns and section headings.
5. Read help for the focused control in a stable footer; restore defaults or use the appropriate value dialog.
6. Settings persist independently of the game save and are restored on the next session.

The preview represents this hierarchy, but native pause integration, full control dialogs, input capture, controller behavior, and visual polish are still required before calling it parity with MCM. Do not substitute eight native category buttons as the shared framework's mod registry.

## Architecture

- `core.lua`: validated mod/page/control definitions, values, callback dispatch, registration lifecycle.
- `store.lua`: per-mod scalar files, temporary write and recoverable backup rename.
- `menu.lua`: navigation, selection, key capture, mouse hit testing, layout commands.
- `view.lua`: stock Stingray GUI/font resource lifecycle.
- `adapter.lua`: MDL API 2 lifecycle, foreground-scoped input, bindable open action, global API publication.

The closed menu polls only its fallback open key plus the optional manager binding. Native drawing is released on close. Active-menu input polling and command rebuilding are unmeasured in-game. No claim of performance parity is made yet.

## Next milestones

1. Live-check stock font, scaling, coordinates, navigation and persistence. Fix visual/input failures before broadening.
2. Native pause-menu entry and consumed keyboard/mouse/controller routing using verified game integration.
3. MCM control dialogs: slider dragging, choice list, key conflict handling, text input and color.
4. Declarative visibility/enabled conditions, version/dependency status, localization, page defaults.
5. JSON author definitions and stable persistence/migration contracts. Version the API before public adoption.
6. Explicit compatibility adapter and public examples. Migrate public HUD settings separately; keep private developer tools outside the distributable.

This document records the original design comparison. Current preview downloads and supported features are listed in the README and release notes. See CREDITS.md and the bundled native-helper license for third-party attribution.
