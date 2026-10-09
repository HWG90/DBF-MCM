# Source organization

| Module | Responsibility |
| --- | --- |
| `core.lua`, `store.lua` | Registration, validation, drafts, callbacks and scalar persistence. |
| `preferences.lua` | MCM's own persisted shortcut, size, scale and font settings. |
| `menu.lua` | Per-menu state, navigation and editor actions. |
| `ui/input.lua` | Keyboard/pointer interpretation, scrolling and drag ownership. |
| `ui/render.lua` | Draw commands, matching hit regions and popup composition. |
| `ui/text.lua`, `ui/theme.lua` | UTF-8 text layout, colors and readable key names. |
| `view.lua` | Stock Stingray primitives, retained geometry and resource cleanup. |
| `capture.lua`, `native/input_guard.c` | Cursor/input ownership and verified restoration. |
| `platform.lua` | Explicit browser action after input restoration. |
| `compat.lua`, `legacy.lua`, `grouping.lua` | Existing registrations and authoritative presentation mounts. |
| `authoring.lua`, `framework.lua` | Creator helpers and framework pages. |
| `console.lua`, `adapter.lua`, `startup.lua` | Diagnostics and loader/runtime lifecycles. |
| `integrations/hud_plus.lua`, `integrations/hud_plus_runtime.lua` | HUD+ owner storage, local bridge discovery and lifecycle. |
| `integrations/native_entry.lua`, `native_ui/` | Verified native Escape tab, cooperating owners and licensed memory/runtime helpers. |

Each menu owns one explicit state table shared by its controller, input and renderer. There are no implicit globals for UI state. Child modules load before the controller; the release builder bundles them into one `dbf_mcm/mod.lua`. The Standalone archive embeds the same runtime and native DLL.

The public consumer contract remains `_G.DBFMCM` API 1. Definitions and saved values stay separate. Input flows through validation, persistence, committed values and callbacks. Confirmation pages hold drafts until Apply; immediate controls bypass staging. Failed writes preserve committed values and suppress callbacks.

Shell/background, row backgrounds, controls and text have distinct depths. Hover keeps primitive counts stable. Unchanged native primitives are retained; stale IDs are destroyed before replacement allocations. HUD preview material uniforms update separately from retained geometry.

Source tests and the actual-compose preview exporter operate offline. Their results do not establish live fonts, geometry, cursor behavior or acceptance.
