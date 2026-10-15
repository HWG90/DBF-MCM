-- Mod Bindings Menu discovery and optional native keyboard editor. MBM owns
-- actions and trigger evaluation; the editor persists MCM keyboard overrides.
local M={}
local function upvalue(fn,wanted)
    if type(fn)~='function'or not debug or type(debug.getupvalue)~='function'then return end
    for index=1,64 do
        local ok,name,value=pcall(debug.getupvalue,fn,index)
        if not ok or not name then return end
        if name==wanted then return value end
    end
end
local function integer(value,maximum)
    return type(value)=='number'and value==value and value%1==0 and value>=0 and value<=maximum
end
local function text(value,fallback)
    if type(value)~='string'or value==''or #value>512 or value:find('[%c]')then return fallback end
    return value
end
local function backend(host)
    if type(host)~='table'or host.api~=1 or host.version~=3 then return nil,'unsupported provider' end
    local state=upvalue(host.register_binding,'state')
    local header=upvalue(host.is_down,'live_header')
    local read=upvalue(header,'read_words')
    local words=upvalue(header,'words')
    if type(state)~='table'or type(state.registry)~='table'or type(state.order)~='table'
        or upvalue(host.is_down,'state')~=state or upvalue(header,'state')~=state
        or type(header)~='function'or type(read)~='function'
        or (type(words)~='cdata'and type(words)~='table')
        or not integer(host.capacity,512)or #state.order>host.capacity then return nil,'unsupported registry' end
    local reader={state=state}
    function reader.snapshot(record)
        if not state.build_rows then return nil,'Native bindings not ready' end
        if state.registry[record.id]~=record then return nil,'Binding registration changed' end
        local bucket,count=header(record);count=tonumber(count)
        if not bucket or not integer(count,16)then return nil,'Native binding unavailable' end
        local function matches()
            return read(bucket,8)and tonumber(words[0])==record.code and tonumber(words[1])==count
        end
        if not matches()then return nil,'Native binding changed; refreshing' end
        local mappings={}
        for index=0,count-1 do
            if not read(bucket+8+index*20,20)then return nil,'Native binding unavailable' end
            -- Copy the shared reader buffer before another provider read.
            local flags,key,trigger,combine,threshold=tonumber(words[0]),tonumber(words[1]),tonumber(words[2]),tonumber(words[3]),tonumber(words[4])
            if not integer(flags,4294967295)or not integer(key,4294967295)
                or not integer(trigger,4294967295)or not integer(combine,4294967295)
                or not integer(threshold,4294967295)then return nil,'Native mapping unavailable' end
            mappings[#mappings+1]={device=flags%16,input=math.floor(flags/16)%16,
                trigger_flags=math.floor(flags/65536)%16,key=key%65536,
                trigger=trigger,combine=combine,threshold_bits=threshold}
        end
        if not matches()then return nil,'Native binding changed; refreshing' end
        return mappings
    end
    return reader
end
local function readable_id(value)
    value=text(value,'Native binding'):match('[^%.:/]+$')or 'Native binding'
    return value:gsub('[_%-]+',' '):gsub('(%a)([%w]*)',function(first,rest)return first:upper()..rest end)
end
-- Confirmed native ship-default codes. These are game input IDs, not the
-- virtual-key IDs accepted by Stingray Keyboard.button_name. Do not guess an
-- offset for unknown/custom mappings; a verified resolver may extend this.
local native_key_names={[58]='Tab',[161]='F1',[165]='F5',[166]='F6',[167]='F7',[168]='F8'}
function M.key_name(code)return native_key_names[code]end
local native_labels={
    [0xb46c8096]='Galactic Map',[0x19e97f02]='Armory',
    [0x2716885e]='Ship Management',[0xe89a91ef]='Hellpod Deployment',
}
local function binding_label(record,options)
    local resolved=text(record.text,text(record.label,nil))
    if not resolved and type(options.localize)=='function'and type(record.label)=='number'then
        local ok,value=pcall(options.localize,record.label)
        if ok then resolved=text(value,nil)end
    end
    return resolved or native_labels[record.label]or readable_id(record.id)
end
local native_description='Mod Bindings Menu owns this binding. Rebind in Options > Mouse & Keyboard > MODS. MCM displays the assigned keys without changing them.'
local editor_description='Select a binding and press its new key. Escape cancels. Right-click > Unbind key clears the keyboard mapping. MBM evaluates the native action; MCM persists keyboard edits. Later native MODS-page edits take priority.'
local function readout(mappings,key_name)
    if #mappings==0 then return 'Not bound' end
    local lines,seen={},{}
    for _,mapping in ipairs(mappings)do
        local name=mapping.device==3 and 'Unknown keyboard key'or 'Other input binding'
        if mapping.device==3 and type(key_name)=='function'then
            local ok,value=pcall(key_name,mapping.key)
            if ok then name=text(value,name)end
        end
        if mapping.trigger~=0 or mapping.trigger_flags~=0 then name=name..' (Custom trigger)'end
        if not seen[name]then seen[name]=true;lines[#lines+1]=name end
    end
    return table.concat(lines,', ')
end
local function group_id(category)
    local hash=5381;for index=1,#category do hash=(hash*33+category:byte(index))%4294967296 end
    return 'native_bindings_'..string.format('%08x',hash)
end
function M.new(api,log,options)
    log=log or function()end;options=options or {}
    local self={};local owner,reader,signature;local handles,rows={},{};local status='host=false';local total=0
    local function clear()
        for _,handle in ipairs(handles)do handle.unregister()end
        handles,rows={},{};signature=nil;total=0
    end
    function self.release()clear();owner,reader=nil,nil;status='host=false';if options.editor then options.editor.release()end end
    function self.diagnostic()return status..' imported='..total end
    function self.poll(host,visible_category)
        if host~=owner then clear();owner=host;reader=nil end
        if not reader and host then local why;reader,why=backend(host);status=reader and 'host=true' or 'host=true '..why end
        if not reader then return end
        if options.editor then options.editor.poll(host,reader.state.order)end
        local groups,entries,parts={},{},{}
        for _,record in ipairs(reader.state.order)do
            if type(record)~='table'or type(record.id)~='string'or reader.state.registry[record.id]~=record
                or not integer(record.code,4294967295)or not integer(record.group,65535)
                or not integer(record.action,65535)or record.code~=record.group*65536+record.action then
                clear();status='host=true unsupported registration';return
            end
            local category=text(record.category,'Other mods'):upper()
            if #category>256 then category='Other mods'end
            local label=binding_label(record,options)
            local has_parent=false
            for id,mod in pairs(api.mods)do
                if not id:match('^native_bindings_')and mod.name:upper()==category and not mod.parent_name then has_parent=true;break end
            end
            groups[category]=groups[category]or {has_parent=has_parent}
            groups[category][#groups[category]+1]={record=record,label=label}
            parts[#parts+1]=category..'\0'..record.id..'\0'..label..'\0'..tostring(record)..'\0'..tostring(has_parent)
        end
        table.sort(parts);local next_signature=table.concat(parts,'\1')
        if signature~=next_signature then
            clear()
            for category in pairs(groups)do entries[#entries+1]=category end;table.sort(entries)
            for _,category in ipairs(entries)do
                local controls={{type='text',label=options.editor and 'Select a binding, then press its new key. Escape cancels.'or 'Rebind in the game\'s MODS controls tab.'}}
                local bindings=groups[category];table.sort(bindings,function(a,b)return a.record.id<b.record.id end)
                local group_rows={}
                for index,entry in ipairs(bindings)do
                    local value={id='binding_'..index,type='text',label=entry.label,description=native_description,
                        text_role='selection',native_binding_value='Unavailable',native_binding_id=entry.record.id}
                    controls[#controls+1]=value;group_rows[#group_rows+1]={record=entry.record,id=value.id}
                end
                local id=group_id(category)
                -- Never overwrite a registration owned by another author.
                if api.mods[id]then status='host=true registration ID occupied';clear();return end
                local has_parent=bindings.has_parent
                local handle=api.register({id=id,name=has_parent and category..' Keybindings'or category,
                    parent_name=has_parent and category or nil,description=options.editor and editor_description or native_description,
                    pages={{id='keybindings',name='Keybindings',require_confirmation=false,controls=controls}}})
                local mod=api.mods[id];mod.pages[1].native_binding_category=category;mod.pages[1].native_binding_description=options.editor and editor_description or native_description
                for _,row in ipairs(group_rows)do
                    for _,control in ipairs(mod.pages[1].controls)do if control.id==row.id then row.control=control;break end end
                    row.category=category;rows[#rows+1]=row
                    if options.editor then
                        local record,control=row.record,row.control
                        control.native_binding_available=function()
                            if host~=owner or reader.state.registry[record.id]~=record then return false,'Binding provider changed'end
                            return options.editor.available(record)
                        end
                        control.native_binding_bind=function(vk)
                            if host~=owner or reader.state.registry[record.id]~=record then return false,'Binding provider changed'end
                            local ok,why=options.editor.bind(record,vk)
                            if ok then
                                local called,mappings=pcall(reader.snapshot,record)
                                if called and mappings then control.native_binding_value=readout(mappings,options.key_name or M.key_name);control.native_binding_snapshot=mappings end
                            end
                            return ok,why
                        end
                        control.description='Select this binding and press a key to save it. Right-click > Unbind key clears the keyboard mapping. MBM still evaluates the native action; MCM saves this keyboard edit. Mouse/controller mappings and activation type are preserved. Later edits in the game\'s MODS page take priority.'
                    end
                    row.description=row.control.description
                end
                handles[#handles+1]=handle
            end
            signature=next_signature;total=#rows;status='host=true'
            log('Imported '..total..' native bindings in '..#handles..' categories')
        end
        if not visible_category then return end
        for _,row in ipairs(rows)do if visible_category==true or row.category==visible_category:upper()then
            local ok,mappings,why=pcall(reader.snapshot,row.record)
            row.control.native_binding_value=ok and mappings and readout(mappings,options.key_name or M.key_name)or 'Unavailable'
            row.control.native_binding_snapshot=ok and mappings or nil
            row.control.description=row.description or native_description
            if not(ok and mappings)then row.control.description=row.control.description..'\n\n'..(ok and why or 'Native binding unavailable')end
        end end
    end
    return self
end
return M
