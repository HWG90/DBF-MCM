-- Standalone typed commands. The current registry and owning handles remain
-- authoritative; completion never reads values, invokes callbacks or saves.
local M={}
function M.for_host(api,loader,diagnostics,options)
    local function valid(bus)return type(bus)=='table'and type(bus.suggest)=='function'and type(bus.execute)=='function'end
    if loader and valid(loader.console)then return loader.console end
    if loader and loader.diagnostics==diagnostics and diagnostics and valid(diagnostics.commands)then return diagnostics.commands end
    return M.new(api,options)
end
local types={toggle='boolean',slider='number',choice='number',keybind='number',input='string',color='string'}
local function utf8(code)
    if code<128 then return string.char(code)
    elseif code<2048 then return string.char(192+math.floor(code/64),128+code%64)
    elseif code<65536 then return string.char(224+math.floor(code/4096),128+math.floor(code/64)%64,128+code%64)
    else return string.char(240+math.floor(code/262144),128+math.floor(code/4096)%64,128+math.floor(code/64)%64,128+code%64)end
end
local function scalar(value)
    if value=='true'then return true elseif value=='false'then return false end
    if value:sub(1,1)=='"'then
        assert(value:sub(-1)=='"','Quoted JSON string required')
        local result={};local at,last=2,#value-1
        local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
        local function unit(index)
            local hex=value:sub(index,index+3);assert(#hex==4 and hex:match('^%x+$'),'Invalid Unicode escape');return tonumber(hex,16)
        end
        while at<=last do
            local ch=value:sub(at,at)
            assert(ch~='"'and ch:byte()>=32,'Invalid JSON string character')
            if ch=='\\'then
                assert(at+1<=last,'Incomplete JSON escape')
                local escaped=value:sub(at+1,at+1)
                if escaped=='u'then
                    assert(at+5<=last,'Incomplete Unicode escape');local code=unit(at+2);at=at+6
                    if code>=0xd800 and code<=0xdbff then
                        assert(value:sub(at,at+1)=='\\u'and at+5<=last,'Unpaired Unicode surrogate')
                        local low=unit(at+2);assert(low>=0xdc00 and low<=0xdfff,'Invalid Unicode surrogate')
                        code=65536+(code-0xd800)*1024+low-0xdc00;at=at+6
                    else assert(code<0xdc00 or code>0xdfff,'Unpaired Unicode surrogate')end
                    result[#result+1]=utf8(code)
                else assert(escapes[escaped],'Invalid JSON escape');result[#result+1]=escapes[escaped];at=at+2 end
            else result[#result+1]=ch;at=at+1 end
        end
        return table.concat(result)
    end
    -- Strict JSON number grammar, rather than Lua's hex/NaN/Inf coercions.
    local at=1
    if value:sub(at,at)=='-'then at=at+1 end
    local digit=value:sub(at,at)
    if digit=='0'then at=at+1 else
        assert(digit:match('^[1-9]$'),'Use a JSON boolean, number or quoted string')
        repeat at=at+1 until not value:sub(at,at):match('^%d$')
    end
    local function digits()
        assert(value:sub(at,at):match('^%d$'),'Invalid JSON number')
        repeat at=at+1 until not value:sub(at,at):match('^%d$')
    end
    if value:sub(at,at)=='.'then at=at+1;digits()end
    local exponent=value:sub(at,at)
    if exponent=='e'or exponent=='E'then at=at+1;local sign=value:sub(at,at);if sign=='+'or sign=='-'then at=at+1 end;digits()end
    assert(at>#value,'Invalid JSON number')
    local number=tonumber(value);assert(number and number==number and math.abs(number)<math.huge,'Finite number required');return number
end
local function describe(value)
    if type(value)=='string'then
        return '"'..value:gsub('[%z\1-\31\\"]',function(ch)
            if ch=='"'then return '\\"'elseif ch=='\\'then return '\\\\'else return string.format('\\u%04x',ch:byte())end
        end)..'"'
    end
    return tostring(value)
end
function M.new(api,options)
    assert(type(api)=='table'and type(api.list)=='function','MCM registry required')
    options=options or {};local self={api=1}
    local get_verbose=options.get_verbose or api.get_verbose
    local set_verbose=options.set_verbose or api.set_verbose
    local function fields()
        local result={}
        for _,mod in ipairs(api.list())do
            if type(mod.id)=='string'and mod.id:match('^[%w_-]+$')and type(mod.handle)=='table'then
                for _,page in ipairs(mod.pages or {})do for _,control in ipairs(page.controls or {})do
                    if type(control.id)=='string'and control.id:match('^[%w_-]+$')and (types[control.type]or control.type=='button')then
                        local path='mods.'..mod.id..'.'..control.id
                        result[path]={type=types[control.type],control=control,handle=mod.handle,key=control.id}
                    end
                end end
            end
        end
        if type(get_verbose)=='function'then result['mcm.verbose_registration']={type='boolean',get=get_verbose,set=type(set_verbose)=='function'and set_verbose or nil,verbose=true}end
        return result
    end
    local function readable(field)return field.type and (field.get or type(field.handle.get)=='function')end
    local function writable(field)return field.type and not(field.control and field.control.disabled)and (field.set or field.handle and type(field.handle.set)=='function')end
    local function callable(field)return field.control and field.control.type=='button'and not field.control.disabled and type(field.handle.activate)=='function'end
    local function paths(snapshot)
        local result={};for path in pairs(snapshot)do result[#result+1]=path end;table.sort(result);return result
    end
    function self.list()return paths(fields())end
    function self.suggest(command)
        if type(command)~='string'or #command>1024 then return {}end
        local result={};local leading,body=command:match('^(%s*)(.-)$')
        local verb,prefix=body:match('^(%a+)%s+([%w_%.%-]*)$')
        if verb and verb~='get'and verb~='run'and verb~='help'and verb~='list'then return result end
        local snapshot=fields()
        local function add(text)result[#result+1]={text=leading..text,label=text}end
        local path,value=body:match('^([%w_%.%-]+)%s*=%s*([%a]*)$')
        if path then
            local field=snapshot[path]
            if field and field.type=='boolean'and writable(field)then
                for _,choice in ipairs({'false','true'})do if choice:sub(1,#value)==value then add(path..' = '..choice)end end
            end
            return result
        end
        prefix=prefix or body;if not prefix:match('^[%w_%.%-]*$')then return result end
        if not verb then for _,word in ipairs({'get ','help','list','run '})do if word:sub(1,#prefix)==prefix then add(word)end end end
        for _,full in ipairs(paths(snapshot))do local field=snapshot[full]
            if full:sub(1,#prefix)==prefix and (verb~='run'or callable(field))and (verb~='get'or readable(field))then add((verb and verb..' 'or '')..full)end
        end
        table.sort(result,function(a,b)return a.text<b.text end);return result
    end
    function self.execute(command)
        local ok,success,message=pcall(function()
            assert(type(command)=='string'and #command<=1024,'Command exceeds 1024 characters')
            command=command:match('^%s*(.-)%s*$');local snapshot=fields()
            if command=='help'or command=='list'or command:match('^help%s+[%w_%.%-]+$')or command:match('^list%s+[%w_%.%-]+$')then
                local prefix=command:match('^%w+%s+([%w_%.%-]+)$');local selected={}
                for _,path in ipairs(paths(snapshot))do if not prefix or path:sub(1,#prefix)==prefix then selected[#selected+1]=path end end
                return true,'Commands:\n'..table.concat(selected,'\n')
            end
            local path,value=command:match('^([%w_%.%-]+)%s*=%s*(.-)%s*$')
            local action=command:match('^run%s+([%w_%.%-]+)$')
            path=path or action or command:match('^get%s+([%w_%.%-]+)$')or command:match('^([%w_%.%-]+)$')
            assert(path,'Use path = JSON scalar, get path, or run path')
            local field=assert(snapshot[path],'Unknown command: '..path)
            local function get()
                assert(readable(field),'Field is not readable: '..path)
                local actual
                if field.get then actual=field.get()else actual=field.handle.get(field.key)end
                assert(type(actual)==field.type,'Unexpected setting value: '..path);return actual
            end
            if value~=nil then
                assert(writable(field),'Setting is unavailable or read-only: '..path)
                local typed=scalar(value);assert(type(typed)==field.type,'Expected '..field.type..' for '..path)
                local accepted,why
                if field.verbose then
                    accepted,why=field.set(typed)
                    -- Core's verbose helper returns the chosen boolean, so
                    -- successfully turning it off returns false. Use readback.
                    local actual=get();if actual~=typed then return false,tostring(why or 'Setter refused')end
                    if accepted==false and why~=nil then return false,tostring(why)end
                    return true,path..' = '..describe(actual)
                else accepted,why=field.handle.set(field.key,typed)end
                if accepted==false then return false,tostring(why or 'Setter refused')end
                return true,type(why)=='string'and why or path..' = '..describe(get())
            elseif action then
                assert(callable(field),'Action is unavailable: '..path)
                local accepted,why=field.handle.activate(field.key)
                return accepted~=false,tostring(why or (accepted==false and 'Action refused'or 'Completed '..path))
            else return true,path..' = '..describe(get())end
        end)
        if not ok then return false,tostring(success)end
        return success,message
    end
    return self
end
return M
