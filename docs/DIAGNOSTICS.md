# Shared diagnostics console (API 1)

Source: `src/console.lua`. Diagnostics, typed command input and bounded log following
borrow the open menu's input ownership. The module never acquires another capture
lease or evaluates Lua. Offline contracts cover the controller; integrated visuals,
focus and input restoration still need game validation.

## Loader integration

Embed the exact module in the loader build and call `Console.shared()`. Both menu
hosts resolve the same `_G.DBFDiagnostics` / `package.loaded['dbf.diagnostics.v1']`
object. Expose it as `LiveLuaLoader.diagnostics` so MCM does not mirror logs twice.
MCM uses that provider and LLL's command bus directly. Its console starts closed
on each menu opening; use **Console** or the grave key to open it. Errors remain
in the shared stream without forcing MCM's console onto the screen.
Discovered readable mod logs register with LLL's existing reader under their
exact loader owner. MCM follows a file itself only when that registration is
unavailable or refused, so accepted files have one reader.

```lua
local diagnostics = Console.shared()
loader.diagnostics = diagnostics
local owner = diagnostics.attach('LLL', actual_log_path)
-- In the existing report/log sink, once per real event:
diagnostics.record('LLL', message, 'info', details, actual_log_path)
-- Before constructing the loader menu:
api.diagnostics = diagnostics
api.diagnostics_surface = Console.surface
```

The MCM menu already consumes those two fields. A separate menu implementation
must create `surface = Console.surface(diagnostics)`, call
`input = surface.filter(input, menu_open)` before parent hit dispatch, and append
`surface.compose(screen_width, screen_height, parent_bounds, menu_open)` after
parent commands. Bounds are physical pixels `{x,y,w,h}` with a bottom-left origin.
Commands are marked `popup=true`, `diagnostic_console=true`; the base plane is 400
and suggestions use higher planes. Do not
feed their text back into allocation diagnostics.

On parent close or handoff, call `surface.release()` to relinquish interaction,
without clearing shared visibility/history/geometry. MCM's `explicit_open` surface
option resets its own open state on release, independent of LLL's visibility.
On completed host shutdown,
call `diagnostics.detach(owner)` after input restoration succeeds. Never acquire a
second input lease for the console. The last detached host hides the window.

## Events and state

`emit({source,severity,message,details,log_path})` accepts `debug`, `info`, `warn`,
or `error`. `record(source,message,severity,details,path)` infers severity when
omitted. Timestamp and display time are assigned by the service. `read()` returns
copies in chronological order. Default retention is 256 events, maximum 512;
adjacent identical events coalesce. Message/details/path lengths are bounded.
Only record real transitions and failures; never dump passwords or text values.
`Console.owner_logger(directory, options)` appends `MCM-<safe-mod-id>.log` in an
existing directory. The adapter uses the loader log directory when available,
otherwise MCM's directory. Invalid IDs are refused; failed writes fall back to the
loader sink. Source mod IDs survive mounted/linked controls. Logging failures do
not change persistence or callback behavior.

Physical VK192 toggles only while a parent menu is open. A held key across
handoff does not toggle twice. The window shares position, size, docking and
scroll state, permits drag/edge resizing, and docks left/right/bottom only when
the rectangle fits outside its parent and inside the screen. History scrolling
pauses following; End resumes. The console consumes its own mouse/wheel and
navigation interactions through the parent's input object.

## Typed input and completion

Click the command field to type. Suggestions update through LLL's typed command
bus when available, otherwise MCM's typed provider. Up/Down selects a suggestion;
**Tab completes without executing**. Enter accepts a visible suggestion, then a
second Enter runs the completed command. Escape dismisses suggestions first, then
leaves editing. Delete clears the draft; Backspace deletes a whole UTF-8 character.
Without suggestions, Up/Down recalls command history. Start with `help` or `list`.

This differs from menu Tab: it accepts the active field/dialog or applies pending
page changes. Shift+Tab moves menu focus while leaving changes pending. Console
typing owns those keys and cannot edit an underlying setting.

`menu.set_command_bus(bus)` requires `suggest(text)` and `execute(text)`.
`surface.focus()` opens editing; `command_state()` returns a copied input and
suggestion snapshot. Pass optional `dt` to `surface.filter` for held-key repeat.
Setters retain the owning mod's validation and persistence rules.

## Verbose registration

The default launch flag is `verbose_registration: false`. In modular LLL, set the
top-level boolean in `LLL/Helldivers2/Settings/dbf_mcm/config.cfg`, preserving its
existing preferences. `mcm.verbose_registration = true` uses the loader config
setter and changes the current runtime only after saving succeeds.

MDL/Shared Loader use `mcm_runtime.ini` beside MCM's per-mod value files as their
fallback launch config. The same explicit command uses that owning writer.
`DBFMCM.set_verbose(boolean)` affects only the current instance; `get_verbose()`
reads it. Verbose registration logs page/category/control counts. Existing UI
settings remain independent and are not reset.

## Direct diagnostics only

MCM does not discover, register, open or poll other mods log files.
Mods report errors directly through the diagnostics API; owned event logging remains available.
