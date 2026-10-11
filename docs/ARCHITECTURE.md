# Source organization

| Module | Responsibility |
| --- | --- |
| `core.lua`, `store.lua` | Registration, validation, drafts, callbacks and scalar persistence. |
| `preferences.lua` | MCM's own persisted shortcut, size, scale and font settings. |
| `menu.lua` | Per-menu state, navigation and editor actions. |
| `ui/input.lua` | Keyboard/pointer interpretation, scrolling and drag ownership. |
| `ui/render.lua` | Draw commands, matching hit regions and popup composition. |
| `ui/text.lua`, `ui/theme.lua` | UTF-8 layout, Epic LUT workspace styling, typography roles and readable key names. |
| `ui/layout.lua`, `ui/branding.lua` | Bounded logical control lanes, responsive details panel, native vector skull and clipped hazard bands. |
| `ui/font.lua`, `view.lua` | Guarded loaded game font, matching ink metrics, retained Stingray primitives and resource cleanup. |
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

The workspace shares Epic LUT's neutral surfaces, gold accents and two-pixel outlined controls. Only headings and titles use bold ink. Existing font-size preferences remain authoritative. Font descriptors stay as hex strings; measurement and drawing use one frozen descriptor per frame, with the stock font as fallback. Popup layers use integer depths, and border strips never cover a control's interior.

Source tests and the actual-compose preview exporter operate offline. Their results do not establish live fonts, geometry, cursor behavior or acceptance.

Window resizing changes available content, not the scale or distance between labels and controls. Rows share a measured control starting edge capped at 400 logical units, and side navigation caps at 400. Wide single-column pages use spare room for contextual details; author-owned columns and preview regions retain their meaning. The UI scale setting scales drawing and matching hit areas together. Default boolean controls are sliding switches; `presentation='checkbox'` is an explicit author choice. Widget tracks, borders and marks occupy separate integer planes, including during hover.

The design references [SkyUI's page/option/help contracts](https://github.com/schlangster/skyui/blob/master/dist/Examples/MCM/ExampleConfigMenu.psc), [Fallout 4 MCM's grouped pages and control types](https://github.com/Neanka/MCM_0.1_AS3/wiki/Menu-Layout), and [r2modman's mod/configuration separation](https://github.com/ebkr/r2modmanPlus). These inform the hierarchy and interaction patterns; the visual treatment follows Helldivers' yellow insignia and hazard bands.
