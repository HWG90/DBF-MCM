# Shared diagnostics console (API 1)

Source: `src/console.lua`. This module has no native dependencies, capture acquisition,
or command execution. The integration is source-ready; live tracking and input
restoration must be tested with the integrated loader before release.

## Loader integration

Embed the exact module in the loader build and call `Console.shared()`. Both menu
hosts resolve the same `_G.DBFDiagnostics` / `package.loaded['dbf.diagnostics.v1']`
object. Expose it as `LiveLuaLoader.diagnostics` so MCM does not mirror logs twice.

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
Commands are marked `popup=true`, `layer=400`, `diagnostic_console=true`; do not
feed their text back into allocation diagnostics.

On parent close or handoff, call `surface.release()` to relinquish interaction,
without clearing shared visibility/history/geometry. On completed host shutdown,
call `diagnostics.detach(owner)` after input restoration succeeds. Never acquire a
second input lease for the console. The last detached host hides the window.

## Events and state

`emit({source,severity,message,details,log_path})` accepts `debug`, `info`, `warn`,
or `error`. `record(source,message,severity,details,path)` infers severity when
omitted. Timestamp and display time are assigned by the service. `read()` returns
copies in chronological order. Default retention is 256 events, maximum 512;
adjacent identical events coalesce. Message/details/path lengths are bounded.
Only record real transitions and failures; never dump passwords or text values.
There is no file writer: existing hosts retain ownership of their log sinks.

Physical VK192 toggles only while a parent menu is open. A held key across
handoff does not toggle twice. The window shares position, size, docking and
scroll state, permits drag/edge resizing, and docks left/right/bottom only when
the rectangle fits outside its parent and inside the screen. History scrolling
pauses following; End resumes. The console consumes its own mouse/wheel and
navigation interactions through the parent's input object.
