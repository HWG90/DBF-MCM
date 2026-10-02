# Integrating a mod

1. Wait for `_G.DBFMCM`; check `api == 1`. Retry on your normal update without logging each miss.
2. Register once per API instance with a globally unique author-prefixed mod ID.
3. Keep a private `owner` variable and handle. If the instance changes, unregister the old handle and register again.
4. Initialize your feature with `handle.get`; registration does not invoke callbacks.
5. Put runtime changes in idempotent callbacks. A successful setting save is not evidence the runtime operation succeeded. Report guarded-operation failures separately.
6. Unregister on disable.

The complete minimal MDL example is `examples/example.lua`. It changes only example settings and logs values. `examples/advanced.lua` demonstrates nested categories, color, a long dropdown and a confirmation page. Copy an example's `mod.lua` into your own MDL folder to try it; keep your IDs distinct.

## Definition design

Use categories for systems (HUD, Audio), pages for focused settings (Colors, Location), sections for related rows within a page. A category's optional parent provides deeper nesting. Setting IDs stay unique across the entire mod. Reorganizing categories should not rename stable IDs.

Use immediate edits for normal settings. Use `require_confirmation=true` for deliberate multi-setting changes or deferred actions. Programmatic set/activate remain explicit immediate methods; UI edit/queue use confirmation. Don't use confirmation as a security boundary.

Use type=color instead of separate RGB sliders when a setting represents one color. Callbacks receive canonical HEX; convert with API.color_rgb. Keybind controls store Windows virtual-key numbers only; they do not register or suppress gameplay actions for you.

## Sharing the dependency

Consumers install DBF-MCM separately. Do not bundle private test payloads, duplicate framework DLLs, or modify another mod's global APIs. Handle an unavailable framework without crashing or enabling sensitive behavior. Source examples are independent of private test tools.
