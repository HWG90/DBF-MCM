![Diver's Best Friend - Mod Configuration Menu](assets/branding/banner.png)

# Mod Configuration Menu — development preview

**Required: MDL API 2 and Bingus Shared Loader. MCM does not currently support standalone installation without MDL. Bingus Mod Options Menu is not required and can be disabled.**

An independent Helldivers 2 configuration framework inspired by the original Skyrim/SkyUI and Fallout 4 MCM. The provisional project name is local; nothing has been published.

The UI has a scrolling mod list on the left, subpages below it, one or two columns of settings on the right, and contextual help and control hints below. Mod registrations are not truncated to eight. It uses stock Stingray GUI/font resources and runs through MDL API 2 without replacing the game's global update callback.

## Current delivery

This is a first executable preview, **not a finished MCM equivalent**. The registry, saved values, keyboard navigation and rendering lifecycle have isolated contract tests. Native drawing, mouse coordinates and key response still require an in-game check. A built-in control showcase provides that check; it changes only its own example settings.

Implemented: toggle, slider, choice, key binding capture, action button, section, text; named pages; optional two-column placement; descriptions; disabled controls; default restoration; per-mod persisted values; callback isolation; late registration and unregister/reload lifecycle; mouse click selection and keyboard navigation.

Not yet implemented: native Escape-menu entry, controller navigation, editable text/color dialogs, dynamic visibility conditions, dependency/version messaging, JSON menu loading, localization, whole-page defaults, and automatic replacement of the native ModOptionsMenu UI. Existing Bingus registrations are mirrored through a compatibility adapter; their original mods remain installed.

## Try the local preview

Run `python native/build.py` (Windows x64 with Visual Studio C++ tools), then `python build.py --install`, refresh MDL's list, enable **Mod Configuration Menu (Preview)**, and press **F10**. The preview now acquires the cursor and filters window keyboard/mouse input while open. This native capture candidate still needs an in-game check; test from the pause menu first. Release mouse buttons before opening. The preview does not pause the simulation. Opening uses physical F10 only. The native binding shortcut is temporarily disabled because its action can alias game navigation.

- Mouse: click a mod, page, or setting. Sliders have draggable handles and clickable tracks; values snap to their configured step and commit on release. Choices have previous/next buttons; toggles and actions have visible controls.
- Tab switches focus between mods and settings.
- Up/Down selects; Left/Right changes a value; Enter activates.
- Page Up/Down selects a subpage; Home restores the selected setting's default.
- F10 or Escape closes; a key-binding prompt uses Escape to cancel.

Values save immediately after accepted edits. **No Apply button** is needed for new API settings. Compatibility pages apply changes immediately through the active provider's values and callbacks. Action callbacks may implement their own confirmation or transaction. This differs from the installed Mod Options Menu's Apply workflow.

Bingus Mod Options Menu can be disabled. DBF-HUD registers its pages directly with MCM, and MCM supplies the ModOptionsMenu compatibility API for existing mods. Restart the game after changing providers so mods can register again.

## For mod authors

Start with [API documentation](docs/API.md) and the [working example](examples/example.lua). Read the [MCM reference and roadmap](docs/MCM-REFERENCE.md) for the intended finished structure.

Definitions and saved values are separate. Settings live under `%LOCALAPPDATA%/MDL/Helldivers2/Mods/dbf_mcm/settings/<mod-id>.ini`; files contain plain scalar values and are never executed. Failed disk writes do not commit the new setting or fire callbacks. Keep IDs stable across releases.

Read [input capture details and limitations](docs/INPUT-CAPTURE.md). Build: `python native/build.py`, then `python build.py`. Verify: `python tests/run.py`. The distributable ZIP contains the standalone MDL mod, documentation, and author example. No private testing payloads are included. Packaging does not establish public licensing, release readiness, or live-game validation.

## Bingus compatibility

Bingus Mod Options Menu is optional. When it is absent, MCM provides its API for toggle, choice and slider registrations, values and change callbacks. Compatibility registrations persist across MCM reloads; Shallow Water Diving was verified live to remain available after reload. If the original menu is enabled, MCM can import its registry instead. Bingus Shared Loader is a separate prerequisite and remains required.

Compatibility with every third-party mod is not yet verified. Original-menu saved values are not automatically migrated, and dynamic translation parity remains unverified. Intermittent dropdown text loss is under investigation.

Mouse wheel: hover the settings area to scroll three rows per notch; hover the left mod list to move through mods. Wheel scrolling leaves setting values unchanged. Raw mouse wheel packets are consumed by the native helper while capture is active.

Scrollbars indicate position in long mod lists, subpage lists and settings pages. Settings also show the current row range. Scrollbar thumbs are position indicators; use the wheel or keyboard to scroll.

Drag the title bar to reposition the menu. Its position survives closing/reopening within this framework session and is clamped to screen bounds, including after resolution changes.

Choice controls open dropdown lists. Scroll the wheel inside an open dropdown, use Up/Down or Page Up/Down, then Enter or click to select. Escape or clicking outside cancels. Long lists have a position scrollbar with click-to-jump support.

Click a slider value box to type a number. The first character replaces the old value; Ctrl+A selects it, Backspace/Delete remove text. Enter validates the range and configured step before committing; Escape or clicking elsewhere cancels. Confirmation pages keep valid edits pending.

