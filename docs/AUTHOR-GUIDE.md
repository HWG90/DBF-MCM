# Mod author quick start

Use `_G.DBFMCM` **API 1**. Call `update()` from your loader's update callback and `disable()` on cleanup. Wait for MCM, register once per API instance, and register again if MCM reloads.

```lua
local owner, settings
local function changed(value, id, previous)
    -- Apply this setting to your feature.
end
local function update()
    local api = rawget(_G, 'DBFMCM')
    if not api or api.api ~= 1 or owner == api then return end
    if settings then settings.unregister() end
    settings = api.register({
        id = 'yourname_example', name = 'Example Mod', on_change = changed,
        pages = {{id = 'general', name = 'General',
            require_confirmation = false, controls = {
                {id = 'enabled', type = 'toggle', label = 'Enabled', default = true},
                {id = 'strength', type = 'slider', label = 'Strength',
                 min = 0, max = 100, step = 1, default = 50},
                {id = 'mode', type = 'choice', label = 'Mode',
                 choices = {'Normal', 'Strong'}, default = 1},
                {id = 'accent', type = 'color', label = 'Accent', default = '#DDB869'},
                {id = 'run', type = 'button', label = 'Run action',
                 on_activate = function() print('Example action') end}
            }}}
    })
    owner = api
    for _, id in ipairs({'enabled', 'strength', 'mode', 'accent'}) do
        changed(settings.get(id), id) -- Initialize saved values.
    end
end

local function disable()
    if settings then settings.unregister() end
    settings, owner = nil, nil
end
```

Keep IDs stable. Prefix your globally unique mod ID; setting IDs must be unique across pages. IDs allow letters, numbers, `_` and `-`, up to 80 bytes. Change display labels freely; mod and setting IDs identify saved values.

| Handle function | Behavior |
| --- | --- |
| `get(id)` / `preview(id)` | Read committed / pending value. |
| `set(id, value)` | Validate and save immediately. |
| `edit(id, value)` | Stage on confirming pages; otherwise save. |
| `reset(id)` | Immediately save the control's default. |
| `set_many({id=value, ...})` | Validate the batch, save once, then notify. |
| `confirm(page)` / `discard(page)` | Apply / clear that page's draft and queued actions. |
| `activate(id)` / `queue(id)` | Run a button / defer it when its `require_confirmation=true`. |
| `unregister()` | Remove your menu; call on disable. |

The example uses immediate settings. Set a page's `require_confirmation=true` for Apply/Discard; specify `false` explicitly for immediate pages. In 0.1.52, a setting's `require_confirmation=false` also overrides its confirming page.

Toggle values are booleans; sliders are snapped numbers; choices are **1-based indexes**; colors are canonical `#RRGGBB`. Buttons store no value. All controls accept `description` and `disabled`. Keybinds store virtual-key numbers; your mod handles the action. Text and sections display information.

Registration restores values **without callbacks**, so initialize from `get`. Control and mod callbacks receive `(value, id, previous)` after a successful save. Unchanged values produce no notification. Failed saves return `false, reason`, preserve values, and fire no callbacks. Invalid definitions or values raise errors. Callback failures are logged after commit; they do not roll back saved settings or game actions.

See [API reference](API.md) for categories, validation, storage providers and linked controls.
