# Cursor and input capture

The preview uses a small Windows x64 helper to subclass only its own game window. It filters keyboard, mouse and raw keyboard/mouse messages while the menu owns the foreground window. The original procedure receives other messages. Lua polls physical key state for menu navigation; there are no Lua callbacks on the window thread.

On acquisition the adapter snapshots Stingray Window mouse focus, cursor visibility and clipping, then shows and confines the cursor and releases relative mouse focus. Closing, disabling, errors or losing foreground ownership release capture and restore those flags. Held menu buttons and keys drain through their releases before ordinary input resumes. Capture refuses acquisition while a mouse button is already held; release it and reopen.

The native DLL is pinned until process exit because another window subclass can retain its callback. Outside capture its callback passes ordinary traffic through, except pending held-input releases. It does not suppress OS input globally or skip game updates. Content-hashed DLL names allow updates without overwriting a loaded library.

## Validation limits

Native policy and held-release tests pass, and Lua lifecycle tests cover cursor restoration, capture failure and capture loss. Actual game input consumption is not yet verified. Direct device polling and controller input are not covered. The opening key may reach the game before the post-update menu acquires capture. This is an input-routing candidate, not a pause or universal device interception mechanism.

Live check: open with F10 after releasing mouse buttons. Move and click the cursor, navigate with arrows, and verify background camera/menu actions do not respond. Close and confirm ordinary controls return. Repeat an Alt-Tab and disable/re-enable check. If background controls still respond, identify that input path before extending interception.

## Build

Run `python native/build.py` with Visual Studio 2022 C++ tools installed, then `python build.py --install`. The installer copies the helper and manifest before atomically replacing the Lua entry point. Existing settings remain intact. Native source is included for inspection.
