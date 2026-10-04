-- Bind declarative data to explicitly supplied Lua behavior. No globals/eval.
local M={}
local callbacks={on_change=true,on_activate=true,validate=true,render_preview=true}
function M.bind(definition,handlers)
    handlers=handlers or {}
    local function copy(value)
        if type(value)~='table' then return value end
        local result={}
        for key,item in pairs(value)do
            if callbacks[key]then
                assert(type(item)=='string','Declarative callback must name a handler')
                assert(type(handlers[item])=='function','Missing Lua handler: '..item)
                result[key]=handlers[item]
            else result[key]=copy(item)end
        end
        return result
    end
    return copy(definition)
end
function M.install(api)
    function api.register_definition(definition,handlers)
        return api.register(M.bind(definition,handlers))
    end
    -- Both menu surfaces read this same handle. Never mirror values locally.
    function api.surface(handle)
        return {get=handle.get,set=handle.edit,preview=handle.preview,
            activate=handle.queue,confirm=handle.confirm,discard=handle.discard,
            revision=function()return api.revision end}
    end
end
return M
