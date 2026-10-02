-- API 1 compatibility for mods using Bingus Mod Options; independent of its UI.
local M={}
function M.new(store,shared)
    local state=shared or {mods={},options={},callbacks={},values={},revision=0}
    local persisted=store and store.load('legacy_options') or {}
    local api={api=1,version=2,max_mods=10000,max_options=10000,mcm_compat=true}
    local function key(id)return 'o_'..id:gsub('.',function(c)return string.format('%02x',c:byte())end)end
    local function text(v,limit)
        if type(v)=='function' then local ok,result=pcall(v);if not ok then return nil end;v=result end
        if type(v)~='string' or #v==0 or #v>limit or v:find('[%c]')then return nil end;return v
    end
    local function normalize(o,v)
        if o.kind=='toggle' then if type(v)=='boolean' then return v end;return nil end
        if type(v)~='number' or v~=v or math.abs(v)==math.huge then return nil end
        if o.kind=='choice' then if v%1==0 and v>=1 and v<=#o.choices then return v end;return nil end
        if v<o.min or v>o.max then return nil end
        return math.min(o.max,o.min+math.floor((v-o.min)/o.step+.5)*o.step)
    end
    function api.register_option(id,spec)
        if type(id)~='string' or #id==0 or #id>96 or id:find('[%c]')or type(spec)~='table' then return false,'invalid option registration' end
        local o={id=id,kind=spec.type,label=text(spec.label,64),description=spec.description and text(spec.description,400) or '',gap=spec.gap==true}
        if not o.label or not o.description then return false,'invalid option text' end
        if o.kind=='toggle' then o.default=spec.default;if o.default==nil then o.default=false end
        elseif o.kind=='choice' then
            if type(spec.choices)~='table' or #spec.choices<2 then return false,'invalid choices' end
            o.choices={};for i,v in ipairs(spec.choices)do o.choices[i]=text(v,48);if not o.choices[i]then return false,'invalid choice text' end end
            o.default=spec.default==nil and 1 or spec.default
        elseif o.kind=='slider' then
            o.min,o.max,o.step=spec.min,spec.max,spec.step or 1
            for _,v in ipairs({o.min,o.max,o.step})do if type(v)~='number' or v~=v or math.abs(v)==math.huge then return false,'invalid slider' end end
            if not o.min or not o.max or o.min>=o.max or o.step<=0 or o.step>o.max-o.min then return false,'invalid slider' end
            o.default=spec.default==nil and o.min or spec.default
        else return false,'unsupported option type' end
        o.default=normalize(o,o.default);if o.default==nil then return false,'invalid default' end
        local existing=state.options[id]
        if existing then
            if existing.kind~=o.kind or existing.default~=o.default or existing.min~=o.min or existing.max~=o.max or existing.step~=o.step or (existing.choices and table.concat(existing.choices,'|')~=table.concat(o.choices or {},'|')) then return false,'option already registered differently' end
            return true
        end
        local title=text(spec.mod or 'Other mods',40);if not title then return false,'invalid mod name' end;title=title:upper()
        local mod=state.mods[title] or {title=title,order={}};state.mods[title]=mod
        o.mod=title;mod.order[#mod.order+1]=o;state.options[id]=o
        local saved=normalize(o,persisted[key(id)]);state.values[id]=saved==nil and o.default or saved
        state.revision=state.revision+1;return true
    end
    function api.get(id)return state.values[id]end
    function api.set(id,value)
        local o=state.options[id];if not o then return false,'unknown option' end
        value=normalize(o,value);if value==nil then return false,'invalid value' end
        local next_values={};for k,v in pairs(persisted)do next_values[k]=v end;next_values[key(id)]=value
        if store then local ok,err=store.save('legacy_options',next_values);if not ok then return false,err end end
        persisted=next_values;state.values[id]=value;return true
    end
    function api.on_change(id,fn)
        if type(id)~='string' or type(fn)~='function' then return false,'invalid callback' end
        state.callbacks[id]=state.callbacks[id] or {};table.insert(state.callbacks[id],fn);return true
    end
    function api.ready()return true end
    return api,state
end
return M
