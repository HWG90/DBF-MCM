# Author API 1 â€” preview contract

Wait for `_G.DBFMCM` in your update, then register once. Re-register if its identity changes after a framework reload. Unregister your handle on disable. Do not copy framework source into every mod.

```lua
local handle = DBFMCM.register({
    id = 'my_mod', name = 'My Mod', description = 'Settings for My Mod.',
    pages = {{id = 'general', name = 'General', controls = {
        {id = 'enabled', type = 'toggle', label = 'Enabled', default = true,
         description = 'Enable the feature.',
         on_change = function(value, id, previous) end},
        {id = 'strength', type = 'slider', label = 'Strength',
         min = 0, max = 100, step = 1, default = 50, column = 2}
    }}}
})
local enabled = handle.get('enabled') -- restored saved value
local ok, err = handle.set('strength', 65)
handle.reset('strength')
-- On mod shutdown:
handle.unregister()
```

IDs use letters, numbers, underscore and hyphen, up to 80 bytes. Mod IDs must be unique across authors; prefix yours. Page IDs are unique within the mod. Setting IDs are unique across all its pages. Invalid definitions fail before the mod is registered. Duplicate registration is rejected; the owner must unregister first.

## Controls

| Type | Required fields | Stored value |
|---|---|---|
| toggle | id, label, default | boolean |
| slider | id, label, min, max, step, default | finite, bounded, snapped number |
| choice | id, label, choices, default | 1-based index |
| keybind | id, label, default | Windows virtual-key code 0â€“255; 0 unbound |
| button | id, label, on_activate | none |
| section/text | label | none |

All support `description`, `column=1|2`, and a static `disabled` flag. Stored controls support `validate(value)` (return false to reject) and `on_change(value, control_id, previous)`. Mod-level `on_change` receives the same arguments. Button callbacks are protected and their errors are reported. A keybind control stores the key; the owning mod handles what it does. It currently has no controller or modifier-chord mapping.

Sliders may set `fine_step` to a positive value no greater than `step` for finer Shift + Left/Right adjustments. Set `commit_on_blur=true` to commit a valid numeric draft when focus moves to another control, page or the menu closes. Enter also commits; Escape cancels the draft. Invalid drafts leave the saved value unchanged. Confirmation pages still stage edits until Apply. Sliders without these options retain their normal step and explicit field-commit behavior.

## Persistence and events

Registration restores persisted values but **does not fire callbacks**. Read `handle.get` immediately and initialize your feature from it. Invalid persisted values fall back to the current definition's default. `set` and `reset` return false plus an error if saving fails; live values remain unchanged and callbacks are not called.

After a successful save, the value is committed and callbacks run independently. A callback error is logged; it does not undo the committed setting. Use `validate` for rejecting values. Callbacks should be idempotent and must not assume notification means a gameplay mutation succeeded. Dynamic dependencies and transactions will need separate contracts before the public API is stabilized.

`handle.set_many({setting_id=value, ...})` validates a complete settings batch, saves once, then publishes values and invokes callbacks. Invalid settings or a failed save leave every value unchanged and invoke no callbacks. Callback failures retain the saved commit, as with `set`. This supports atomic preset imports; it does not make native/game operations transactional.

`DBFMCM.list()` returns all currently registered mods sorted by display name then ID. `DBFMCM.get(mod_id, setting_id)` and `set` forward to its handle. `open()`, `close()`, `is_open()` control the preview. The registry has no eight-mod limit. Definitions must currently be Lua tables; JSON discovery is planned.

## Compatibility boundaries

This is an independent API, not a drop-in global replacement for CowboyBingus ModOptionsMenu or Bethesda's Papyrus/F4SE APIs. Never overwrite another framework's global. ModOptionsMenu compatibility must be implemented as an explicit adapter and tested against existing callbacks and saved IDs. Existing registrations cannot be recovered solely through its public `get`/`set` interface.

## Pages requiring confirmation

Set `require_confirmation = true` on a page definition. Pages require confirmation by default; use `require_confirmation=false` for immediate pages. Button actions are staged only when the button itself sets `require_confirmation=true`. The menu stages deferred edits and explicitly queued actions and displays APPLY and DISCARD buttons. Navigating away or closing keeps the draft in memory; reload/unregister drops it. Pending edits are never persisted automatically.

`handle.edit(id, value)` stages on confirmation pages and saves immediately elsewhere. `handle.preview(id)` reads a draft if present; `handle.get(id)` always reads committed settings. `handle.queue(button_id)` stages only buttons with `require_confirmation=true`; other buttons run immediately. `handle.confirm(page_id)` revalidates, saves all page settings in one write, commits them, then invokes setting callbacks and queued actions. A failed save keeps the draft and invokes no callbacks/actions. `handle.discard(page_id)` clears the draft and queued actions.

Programmatic `set`, `reset` and `activate` remain explicit immediate operations. Confirmation is a UI workflow, not an authorization boundary. Callback/gameplay operations are not transactional: an action failure does not roll back committed settings or earlier callbacks. Mod authors should implement guarded operations and report their own runtime outcome.

```lua
pages = {{ id = 'advanced', name = 'Advanced',
    require_confirmation = true, controls = {
        {id = 'enabled', type = 'toggle', label = 'Enable', default = false}
    }
}}
```

## Categories and submenus

Define ordered `categories` on the mod; pages reference a category by ID. Categories can reference a `parent` category for deeper nesting. The sidebar renders expandable headings and indented pages, with wheel scrolling and a position scrollbar. IDs must be unique; missing parents, unknown page categories and cycles are rejected before registration. Omitting categories preserves flat pages. Settings IDs remain mod-wide, so changing grouping does not change persistence keys.

```lua
DBFMCM.register({
  id='my_mod', name='My Mod',
  categories={{id='hud', name='HUD'}},
  pages={
    {id='colors', name='Colors', category='hud', controls={}},
    {id='location', name='Location', category='hud', controls={}},
    {id='misc', name='Misc', category='hud', controls={}}
  }
})
```

For nested systems add `{id='advanced', name='Advanced', parent='hud'}` and assign pages to `advanced`. Existing Bingus registrations stay flat until adapted; grouping is not guessed from option labels.

The compatibility adapter explicitly groups DBF-HUD Layout Editor and DBF-HUD Placement beneath DBF-HUD. Their original Bingus option IDs, persistence and callbacks remain unchanged. This is an adapter rule, not automatic name-based grouping for all mods.

## Color control

`{id='accent', type='color', label='Accent', default='#F4CA35'}` opens an RGB/HEX picker with a preview swatch. Accepts `#RRGGBB` or `RRGGBB`, and RGB tables `{255,128,0}` or `{r=255,g=128,b=0}`. Channels must be integers 0-255. Values and callbacks use canonical uppercase `#RRGGBB`. `DBFMCM.color_rgb(value)` returns three channels; `color_hex(value)` normalizes a value. No alpha channel in this version. Valid typed fields update the preview when focus leaves the field (Enter also works); USE COLOR commits the color or stages it on a confirmation page. CANCEL leaves the setting unchanged.

The picker also offers a draggable hue/saturation spectrum and brightness strip. SAVE SWATCH stores the current preview in a shared persistent palette (12 most recent unique colors). `DBFMCM.save_swatch(value)` returns success/error; `DBFMCM.swatches()` returns canonical HEX strings. Palette persistence is independent of the edited mod and does not apply its color setting.

Select a custom swatch (outlined in yellow), edit its color, then click REPLACE to overwrite that slot. SAVE SWATCH still adds a color. `DBFMCM.replace_swatch(index, value)` overwrites an existing 1-based slot and returns success/error; failed writes leave the palette unchanged.

## ModOptionsMenu compatibility

When the original menu is absent, MCM provides API 1 register_option/get/set/on_change/ready for toggles, choices and sliders. Its shared registry survives MCM reloads. Legacy registration limits are expanded. Translation functions resolve at registration; full dynamic translation parity is not yet verified. Existing original-menu settings are not automatically migrated. Test each mod live. Restart the game if registrations were already lost before the preservation fix.

Native `ModBindingsMenu` API 1/version 3 registrations also appear on a **Keybindings** page under the matching mod category. MCM uses the existing registered action IDs, including First Person's `firstperson.toggle`; it does not register replacement actions or substitute Windows-key polling for MBM activation. An absent or unsupported native provider is not replaced.

Select an MBM keyboard field and press a key to save it; Escape cancels. One simple keyboard mapping is editable, with its trigger/threshold and all other devices preserved. Multiple-key or chord bindings remain read-only in MCM and editable through **Options > Mouse & Keyboard > MODS**. Native key IDs are converted separately from MCM's ordinary VK controls.

MCM persists keyboard overrides in `mbm_bindings.ini`, keyed by stable MBM binding ID. It restores an edit only while the original native baseline still matches; later native-page edits retire the override. Writes require a validated game build, current vector/action identity and matching readback, then update MBM's existing sweep fingerprint. Failed persistence rolls the native map back. MCM does not alter the game's input settings file or overwrite controller/mouse bindings.
# Diagnostics integration

The shared read-only console contract is documented in [DIAGNOSTICS.md](DIAGNOSTICS.md).

## Storage and presentation capabilities (0.1.51)

`storage_per_mod`, `presentation_links` and `text_swatches` advertise these extensions. Registration can supply `storage={load=function(mod_id) ... end, save=function(mod_id,values) ... end}`. Save returns success or `false, reason`; the provider owns that mod's persistence across framework changes.

A presentation control can set `source_mod_id` and `source_control_id` to route reads/writes to an existing registered control. Give the alias its own ID and compatible type/range. Missing references are omitted; disabled aliases reject writes. Keep the referenced provider registered.

Display-only text controls can include `swatches={{rgb={255,128,0},row=1}, ...}`. Up to eight swatches render with stock rectangles/text and store no value.

`focus_page(mod_id,page_id)` opens a registered page when the game is focused and returns success/error. `menu_binding_status()` exposes focus, active editors and the configured menu virtual key. Opening remains subject to capture/ownership checks.

## UI refresh behavior (0.1.53)

Controls with `require_confirmation=false` commit immediately even on a confirming page. Other edits remain pending until Apply; disk failures retain the pending values and suppress callbacks. Linked presentation controls keep the referenced handle authoritative. `menu_binding_status().global_key` reports the saved Open/Close key, default 46 (DEL). Settings uses the framework's authoritative handle. Apply, Discard and Reset Setting are buttons; no secondary action shortcuts are assigned. Delete used inside text or key-binding editors is owned by the editor.


## Camera input candidate

`DBFMCM.camera_input` API 2 uses the shared native window handler and external
input lease. `acquire()` returns a token or nil/reason and refuses competing
menus or unfocused windows. Held movement keys do not prevent capture.
`sample()` returns WASD, Shift/up, Ctrl/down, Escape, signed wheel units (120 per
notch), captured mouse deltas and real-time `dt`, or nil after ownership/focus
loss. `release()` returns true or false/reason; failed cursor restoration retains
ownership for retry. `down(vk)` and `focused()` poll physical foreground input.
`now()` (0.1.58) returns native monotonic seconds independently of simulation
speed or input-lease ownership. It remains available while the photo menu has
focus and after capture release. Feature-detect it before use; adapters without
a native clock do not expose this optional method.
MCM opening and provider shutdown release this capture. Consumers must release
on scene loss, error and shutdown, and stop moving when sampling returns nil.
Native mode 3 captures photo input; `set_focus(true)` switches the owned lease to
menu mode 1 for `menu_sample()`, and `set_focus(false)` restores mode 3. Only one
camera consumer may own this API. It requires the matching DLL and a normal
game restart; consumer integration still needs its own live validation.


Photo input API 2 candidate: `camera_input.isolated_look=true` advertises fully
captured raw mouse motion. `sample()` includes mouse_x, mouse_y and a monotonic
real-time dt, independent of simulation time. Native capture mode 3 captures all
keyboard/buttons/wheel/motion; game mouse focus is disabled during the owned lease
and restored from the original snapshot. Menu capture keeps its existing behavior.
This replaces mode-2 passthrough for photo consumers and requires the new DLL.

Photo pause protection: the native input DLL requires known session state with zero other and synchronizing peers (or zero offline connections) before invoking the engine pause setter. Unknown/error state denies pause. Freecam remains usable in multiplayer without pause. Active pause is rechecked and restored when peers join. Held keyboard and mouse input no longer blocks photo capture; prior gameplay releases are forwarded with gameplay mouse focus disabled. Each activation starts from the current gameplay camera position.
