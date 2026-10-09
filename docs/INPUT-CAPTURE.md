# Cursor and input capture

The preview uses a small Windows x64 helper to subclass only its own game window. It filters keyboard, mouse and raw keyboard/mouse messages while the menu owns the foreground window. The original procedure receives other messages. Lua polls physical key state for menu navigation; there are no Lua callbacks on the window thread.

On acquisition the adapter snapshots Stingray Window mouse focus, cursor visibility and clipping, then shows and confines the cursor and releases relative mouse focus. Closing, disabling, errors or losing foreground ownership release capture and restore those flags. Held menu buttons and keys drain through their releases before ordinary input resumes. Capture refuses acquisition while a mouse button is already held; release it and reopen.

The native DLL is pinned until process exit because another window subclass can retain its callback. Outside capture its callback passes ordinary traffic through, except pending held-input releases. It does not suppress OS input globally or skip game updates. Content-hashed DLL names allow updates without overwriting a loaded library.

## Validation limits

Native policy and held-release tests pass, and Lua lifecycle tests cover cursor restoration, capture failure and capture loss. Actual game input consumption is not yet verified. Direct device polling and controller input are not covered. The opening key may reach the game before the post-update menu acquires capture. This is an input-routing candidate, not a pause or universal device interception mechanism.

Live check: open with the configured key (DEL by default) after releasing mouse buttons. Move and click the cursor, navigate with arrows, and verify background camera/menu actions do not respond. Close and confirm ordinary controls return. Repeat an Alt-Tab and disable/re-enable check. If background controls still respond, identify that input path before extending interception.

## Build

Run `python native/build.py` with Visual Studio 2022 C++ tools installed, then build the packages with `build.ps1` and follow the selected loading route in [Installation](INSTALL-STANDALONE.md). Python installation is disabled. Preserve existing settings when switching providers. Native source is included for inspection.

## Restoration failures and loader handoff

Cursor restoration treats setter exceptions and explicit `false` returns as failures. The menu releases its native gate but retains the exact cursor snapshot until every setter succeeds. Closed-menu updates retry restoration; acquisition is refused while a previous restore remains pending. Foreign input leases remain owned by their token and cannot be released by ordinary menu close.

`DBFMCM.close()` returns `true` on successful restoration or `false, reason` when ownership/restoration prevents it. `DBFMCM.input_status()` reports `owner`, `active`, and `pending_restore` without acquiring capture. Shutdown retains the provider when restoration is pending so deferred cleanup can retry.

A matching Live Lua Loader must expose `close_manager()` with the same success/failure convention. Before MCM acquires capture, it closes the independent loader manager and only then snapshots game cursor flags. The loader must likewise respect a failed MCM close before opening its manager. MCM refuses opening with an older loader that exposes `open_manager()` but lacks `close_manager()`; deploy matched implementations together. This prevents recording another menu's released mouse focus as the game baseline.

Focused offline checks:

```powershell
python tests/run.py --suite tests/capture_recovery.lua
# Set this to your matching LLL source checkout for the integration checks.
$env:DBF_LLL_ROOT = 'C:/path/to/LLL'
python tests/run.py --suite tests/handoff_recovery.lua
python tests/run.py --suite tests/manager_handoff.lua
```

These checks cover refused setters, exceptions for all three cursor flags, retry without reacquisition, focus loss, foreign leases, ordered handoff, and actual loader-manager close failure propagation. They do not prove live-game behavior of the permanent candidate. Repeat the live checks above with both repaired components installed before treating the handoff as validated.
