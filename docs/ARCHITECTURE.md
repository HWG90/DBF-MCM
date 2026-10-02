# Architecture

## Module boundaries

| Module | Responsibility | Depends on |
| --- | --- | --- |
| `src/core.lua` | Definition validation, registration, normalized values, confirmation drafts, callbacks, shared swatches | Injected store/logger |
| `src/store.lua` | Plain INI-like scalar persistence with temp/backup replacement | Lua file API |
| `src/menu.lua` | Menu state, tree, input interpretation, controls, dropdown/color dialogs; emits draw commands | Registry API |
| `src/view.lua` | Draw-command renderer and GUI resource cleanup | Stingray GUI |
| `src/capture.lua` | Cursor ownership snapshot, acquisition/release/error lifecycle | Native helper and Stingray Window |
| `src/legacy.lua` | Existing Bingus registration import and explicit HUD grouping | Existing ModOptionsMenu + registry |
| `src/adapter.lua` | MDL API 2 entry point, physical input polling, F10, lifecycle and module composition | All modules |
| `native/input_guard.c` | Foreground game-window keyboard/mouse message filtering; wheel accumulation | Windows APIs |

The build wraps each Lua module into a local `MCM` namespace, then returns the MDL adapter. It publishes only `_G.DBFMCM` as the consumer contract. Consuming mods provide definitions and callbacks; they do not need the renderer, native input helper or persistence implementation.

## Data flow

Definition -> validate entire definition -> load valid saved values -> publish registration handle. UI input -> preview/edit -> validate -> persist -> commit -> callback. On confirmation pages, edit/queue -> in-memory draft -> Confirm -> revalidate all -> one settings write -> commit -> callbacks/actions. Closing retains page drafts until unregister/reload. Color picker previews are separate and commit only through Use Color. Swatch saves have their own shared file.

Renderer commands carry position, size, color and optional layer. Menu is layer 100, dropdowns 200, color dialogs 300, with small per-command ordering offsets. Keep depth values bounded. The view destroys previous primitives each frame; optimizing retained primitives is future work.

## Lifecycle

MDL enables adapter -> creates modules and publishes API -> consuming mods register. Update imports legacy pages, polls input, updates menu, syncs capture and draws. Disable/error releases capture and GUI and unpublishes owned API. Consumers must detect API identity changes and re-register. The native callback is pinned until process exit; capture release makes it pass ordinary traffic while draining held menu inputs.

## Extending controls

Add a type to core validation and normalization, define its persisted representation, implement menu interactions and draw commands, then add meaningful contracts for failures and confirmation behavior. Extend store only with constrained data formats; never execute settings files. Preserve mod-wide setting IDs when reorganizing pages. Validate before mutating the registry. Handle.get is the committed view; preview is the draft view.

## Legacy bridge

Reads the `state` upvalue from the installed register_option function; does not replace its global API. Values use host.get/set and original callbacks. Imports are rebuilt when registry revision changes. DBF-HUD's Layout Editor and Placement are explicitly grouped into one root; generic prefix guessing is avoided. Imported defaults and values remain owned by the legacy host. Public author integrations should use DBFMCM directly.
