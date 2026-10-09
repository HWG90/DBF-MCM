-- Native Escape tab: derived from CowboyBingus ModOptionsMenu (Zero-Clause BSD).
-- src/native_ui/LICENSE covers its guarded memory/runtime helpers.
local N={}
local L={bar=1248,count=57448,current=57452,labels=57320,capacity=8,
    button_state=11004,button_active=11021,text=8296,stride=3400,shown=8,
    label=272,args=280,arg_count=616,template=0xc67c7faf,key=0xab2a7b35}
local BUILD={exe_sha256='F5FEE03DCFDB2E553A4752C283590950AC13316B376D8196AA556FF0400D5F06',
    game_sha256='2E2C3B7C2500646DADD5F2B4C6E0504DBB7E7896139F64CDDC0D1813C718F51E'}
local LABELS={0xd876b36e,0x78934e12,0x8c02bd80}
local function hex(value)return (value:gsub('%x%x',function(pair)return string.char(tonumber(pair,16))end))end
local CALLS={
    set_tabs={0x17aac50,'\x48\x89\x54\x24\x10\x53\x56\x48\x83\xec\x68\x0f\x29\x74\x24\x30','void (*)(uint64_t,const uint32_t *,int)'},
    set_label={0x143bf90,'\x48\x83\xec\x28\x4c\x8b\xd9\x39\x91\x10\x01\x00\x00\x0f\x84\x80','void (*)(uint64_t,uint32_t)'},
    set_string={0x143c950,'\x40\x53\x48\x83\xec\x20\x48\x8b\xd9\x48\x81\xc1\x10\x01\x00\x00','void (*)(uint64_t,uint32_t,const char *)'},
    tab_switch={0x1474370,hex('48895c2408574883ec508b41088bda488bf9'),'void (*)(uintptr_t,int32_t)',hex('ffffffff00ffffffffffffff00ffffffffff')},
    tab_select={0x17abfc0,hex('48895c240848896c24104889742418574883ec204863816ce00000'),'void (*)(uintptr_t,int32_t,uint8_t,uint8_t)',hex('ffffffff00ffffffff00ffffffff00ffffffffffffffff00000000')}
}
local function signature_matches(actual,expected,mask)
    if type(actual)~='string'or #actual~=#expected then return false end
    if not mask then return actual==expected end
    if #mask~=#expected then return false end
    for index=1,#expected do
        local keep=mask:byte(index)
        if keep~=0 and (keep~=255 or actual:byte(index)~=expected:byte(index))then return false end
    end
    return true
end
N.layout,N.build=L,BUILD
local function copy(value)local result={};for key,item in pairs(value or {})do result[key]=item end;return result end
local function pack(...)return {n=select('#',...),...}end
local function pointer(value)return type(value)=='number'and value>=0x10000 and value<0x800000000000 and value%8==0 end
local function word(bytes,offset)
    offset=offset or 0;local a,b,c,d=bytes:byte(offset+1,offset+4)
    return a+b*256+c*65536+d*16777216
end
local function source(name)
    local path=debug.getinfo(1,'S').source:sub(2):gsub('\\','/')
    local folder=assert(path:match('^(.*)/[^/]+$'),'Native entry source path unavailable')
    return assert(loadfile(folder..'/../native_ui/'..name..'.lua'))()
end

-- Constructed only during explicit install. Tests inject a backend and never enter it.
function N.windows(options)
    options=options or {};local deps=options.dependencies or {}
    local ffi=options.ffi or require('ffi')
    local runtime=deps.runtime or source('bingus_runtime')
    local memory=(deps.memory or source('bingus_memory')).new(runtime)
    local self={};local base,native,lease;local tab_labels=ffi.new('uint32_t[8]')
    local pin=package.loaded['dbf_mcm.native_entry.text.v1']
    if type(pin)~='table'then pin={};package.loaded['dbf_mcm.native_entry.text.v1']=pin end
    if not pin.buffer then pin.buffer=ffi.new('char[4]','MCM')end
    local text_address=tonumber(ffi.cast('uint64_t',pin.buffer))
    local function read_bytes(address,size)return memory.read(ffi.cast('const void *',address),size)end
    local function read(address,size)
        local bytes=read_bytes(address,size);assert(bytes,'Native menu read unavailable');return bytes
    end
    local function get32(address)return word(read(address,4))end
    local function get8(address)return read(address,1):byte()end
    local function get_pointer(address)
        local bytes=read_bytes(address,8);if not bytes then return nil end
        local value=word(bytes)+word(bytes,4)*4294967296
        return pointer(value)and value or nil
    end
    local function live(screen)
        local current,status=self.escape_menu()
        assert(status=='open'and current==screen and lease==screen,'Native Escape owner changed')
    end
    local function put32(address,value)ffi.cast('uint32_t *',address)[0]=value end
    local function put8(address,value)ffi.cast('uint8_t *',address)[0]=value end
    function self.verify()
        local valid,why=memory.verify_build(BUILD);if not valid then return false,why end
        base=memory.address(memory.module('game.dll'));native={}
        for name,entry in pairs(CALLS)do
            if not signature_matches(read_bytes(base+entry[1],#entry[2]),entry[2],entry[4])then return false,'Native '..name..' signature changed'end
            native[name]=ffi.cast(entry[3],base+entry[1])
        end
        for index,label in ipairs(LABELS)do
            if get32(base+0x33114d0+(index-1)*4)~=label then return false,'Native tab labels changed'end
        end
        return true
    end
    function self.escape_menu()
        if not base then return nil,'closed'end
        local ui=get_pointer(base+0x347ce28);if not ui then lease=nil;return nil,'closed'end
        local stack=read_bytes(ui+0x429c,24);if not stack then lease=nil;return nil,'closed'end
        local depth=word(stack,20);if depth>5 then lease=nil;return nil,'closed'end
        local open=false;for index=0,depth-1 do if word(stack,index*4)==1 then open=true end end
        if not open then lease=nil;return nil,'closed'end
        if word(stack,(depth-1)*4)~=1 then lease=nil;return nil,'covered'end
        local menu=get_pointer(base+0x347ce38);local screen=menu and get_pointer(menu+200)
        if not screen then lease=nil;return nil,'closed'end
        return screen,'open'
    end
    function self.snapshot(screen)
        local current,status=self.escape_menu()
        assert(current==screen and status=='open','Native Escape is not on top')
        assert(memory.writable_data(screen,L.shown+4)and memory.writable_data(screen+L.bar,L.count+8),'Native menu storage is not writable')
        local count=get32(screen+L.bar+L.count);local selected=get32(screen+L.bar+L.current)
        assert(count>=3 and count<=L.capacity and selected<count,'Native tab bounds changed')
        local labels={};local bytes=read(screen+L.bar+L.labels,count*4)
        for index=1,count do labels[index]=word(bytes,(index-1)*4)end
        for index=1,3 do assert(labels[index]==LABELS[index],'Native base tab ownership changed')end
        lease=screen;return {count=count,current=selected,labels=labels,shown=get32(screen+L.shown)}
    end
    function self.apply_tabs(screen,labels,selected)
        live(screen);assert(#labels>=3 and #labels<=L.capacity and selected<#labels,'Invalid native tab request')
        for index,label in ipairs(labels)do tab_labels[index-1]=label end
        native.set_tabs(screen+L.bar,tab_labels,#labels)
        local button=screen+L.bar+L.stride*selected
        put32(screen+L.bar+L.current,selected);put32(button+L.button_state,3);put8(button+L.button_active,1)
    end
    function self.set_count(screen,count)live(screen);assert(count>=3 and count<=L.capacity);put32(screen+L.bar+L.count,count)end
    function self.show_text(screen,index)
        live(screen);assert(index>=3 and index<L.capacity)
        local widget=screen+L.bar+L.text+L.stride*index
        native.set_label(widget,L.template);native.set_string(widget,L.key,pin.buffer)
    end
    function self.owns(screen,index)
        local widget=screen+L.bar+L.text+L.stride*index
        if get32(widget+L.label)~=L.template then return false end
        local count=get8(widget+L.arg_count);if count>14 then return false end
        for slot=0,count-1 do
            local record=widget+L.args+24*slot
            if get32(record)==L.key and get32(record+4)==1 then return get_pointer(record+8)==text_address end
        end
        return false
    end
    function self.restore_selection(screen,index,shown)
        local snapshot=self.snapshot(screen)
        assert(index>=0 and index<snapshot.count and shown>=0 and shown<=2,'Previous native selection unavailable')
        live(screen);native.tab_switch(screen,shown)
        live(screen);native.tab_select(screen+L.bar,index,0,0)
    end
    return self
end

local function upvalue(fn,wanted)
    for index=1,64 do local name,value=debug.getupvalue(fn,index);if not name then break end;if name==wanted then return value,index end end
end
local function mom_step(env,root)
    local diagnostic={nodes=0,candidates=0,state=false,node_limit=256,depth_limit=32,c_skipped=0,depth_limited=0,budget_exhausted=false,candidate_details={}}
    local host=rawget(env,'ModOptionsMenu')
    local register=type(host)=='table'and rawget(host,'register_option')
    local api_state=type(register)=='function'and upvalue(register,'state')
    if type(api_state)~='table'then return nil,nil,nil,diagnostic end
    diagnostic.state=true
    local queue,seen,at={},{},1
    local function enqueue(fn,depth)
        if type(fn)~='function'or seen[fn]then return end
        if depth>32 then diagnostic.depth_limited=diagnostic.depth_limited+1;return end
        local info=debug.getinfo(fn,'S')
        if not info or info.what=='C'then diagnostic.c_skipped=diagnostic.c_skipped+1;seen[fn]=true;return end
        seen[fn]=true;queue[#queue+1]={fn=fn,depth=depth,info=info}
    end
    local function hook_edges(hook,depth)
        if type(hook)~='table'or type(rawget(hook,'base'))~='function'then return end
        local driver=rawget(hook,'driver')
        if type(driver)~='table'or type(rawget(driver,'frame'))~='function'then return end
        enqueue(rawget(hook,'base'),depth);enqueue(rawget(driver,'frame'),depth)
    end
    local function names(fn)
        local result={};for slot=1,64 do local name=debug.getupvalue(fn,slot);if not name then break end;result[#result+1]=name~=''and name or '<anonymous>'end
        return table.concat(result,',')
    end
    enqueue(root or rawget(env,'update'),0)
    while at<=#queue and diagnostic.nodes<256 do
        local node=queue[at];at=at+1;local fn,depth=node.fn,node.depth
        diagnostic.nodes=diagnostic.nodes+1
        local ensure,slot=upvalue(fn,'ensure_mods_tab')
        if type(ensure)=='function'then
            diagnostic.candidates=diagnostic.candidates+1
            diagnostic.bar=upvalue(fn,'TAB_BAR');diagnostic.tab=upvalue(fn,'MODS_TAB')
            diagnostic.step_state=upvalue(fn,'state')==api_state;diagnostic.ensure_state=upvalue(ensure,'state')==api_state
            diagnostic.candidate_short_src=node.info.short_src;diagnostic.candidate_upvalues=names(fn)
            local info=debug.getinfo(ensure,'S');diagnostic.ensure_short_src=info and info.short_src;diagnostic.ensure_upvalues=names(ensure)
            if #diagnostic.candidate_details<8 then diagnostic.candidate_details[#diagnostic.candidate_details+1]={short_src=diagnostic.candidate_short_src,upvalues=diagnostic.candidate_upvalues,ensure_short_src=diagnostic.ensure_short_src,ensure_upvalues=diagnostic.ensure_upvalues,bar=diagnostic.bar,tab=diagnostic.tab,step_state=diagnostic.step_state,ensure_state=diagnostic.ensure_state}end
        end
        if type(ensure)=='function'and upvalue(fn,'TAB_BAR')==L.bar and upvalue(fn,'MODS_TAB')==3 and upvalue(fn,'state')==api_state and upvalue(ensure,'state')==api_state then return fn,slot,ensure,diagnostic end
        -- Breadth first: helper trees cannot consume the whole budget before
        -- a nearby update-chain sibling. Prioritize actual forwarding edges.
        for _,name in ipairs({'previous_update','original_update','originalUpdate','previousUpdate','previous','original','old_update','oldUpdate','upstream','next_update','inner','step','update','run','finish'})do
            enqueue(upvalue(fn,name),depth+1)
        end
        hook_edges(upvalue(fn,'hook'),depth+1)
        -- Stripped loader wrappers keep closure values but lose their names.
        -- Anonymous functions may lead to named MOM; an anonymous MOM callback
        -- itself is never guessed or rewritten.
        for slot=1,64 do
            local name,value=debug.getupvalue(fn,slot);if not name then break end
            if name==''then
                if type(value)=='function'then enqueue(value,depth+1)
                elseif type(value)=='table'then hook_edges(value,depth+1)end
            end
        end
        -- Other loaders use names such as callback/dispatch. Reading Lua
        -- closure edges is harmless; only the authenticated MOM slot is patched.
        for slot=1,64 do
            local name,value=debug.getupvalue(fn,slot);if not name then break end
            if type(value)=='function'then enqueue(value,depth+1)end
        end
    end
    diagnostic.budget_exhausted=at<=#queue
    return nil,nil,nil,diagnostic
end

function N.new(api,options)
    options=options or {};local env=options.env or _G
    local self={};local backend,verified,retired,retiring,record,parent,gameplay,wrapper,previous
    local bridge,hud_bridge;local hud_wait=false;local last_reason;local last_mom_scan,last_mom_detail;local last_state;local last_selection
    local function note(reason)if reason~=last_reason then last_reason=reason;if options.log then options.log('MCM native entry: '..tostring(reason))end end end
    local function initialize()
        if verified then return true end
        backend=backend or options.backend or N.windows(options)
        local valid,why=backend.verify();if not valid then note(why);return false,why end
        verified=true;return true
    end
    local function observed()
        local screen,status=backend.escape_menu();if status~='open'then return screen,status end
        return screen,status,backend.snapshot(screen)
    end
    local function own(screen,snapshot)
        return record and record.screen==screen and snapshot.count>record.index and snapshot.labels[record.index+1]==L.template and backend.owns(screen,record.index)
    end
    local function remove()
        if not record then return true end
        local screen,status,snapshot=observed()
        if status=='closed'then record=nil;return true end
        if status~='open'then return false,'Native Escape is covered; cleanup pending'end
        if screen~=record.screen then record=nil;return true end
        if not own(screen,snapshot)then return false,'Native MCM tab ownership changed'end
        if snapshot.count~=record.index+1 then return false,'Another native tab follows MCM; cleanup pending'end
        if snapshot.current==record.index then backend.restore_selection(screen,record.previous,record.previous_shown);snapshot=backend.snapshot(screen)end
        local labels={};for index=1,record.index do labels[index]=snapshot.labels[index]end
        backend.apply_tabs(screen,labels,snapshot.current);record=nil;return true
    end
    local function publish(screen,snapshot)
        if record and record.screen~=screen then record=nil end
        if record then
            if not own(screen,snapshot)then return false,'Native MCM tab ownership changed'end
            if snapshot.current~=record.index then record.previous=snapshot.current;record.previous_shown=snapshot.shown end
            return true
        end
        if hud_wait then
            local worker=hud_bridge and hud_bridge.instance;local slot=worker and worker.slot
            if not hud_bridge or not hud_bridge.after_place or type(slot)~='number'or slot%1~=0 or slot<3 or slot>=snapshot.count or snapshot.labels[slot+1]~=worker.n.menu_text_tab then return false,'Waiting for native HUD+ tab placement'end
            local okay,intact=pcall(worker.label_is,worker,screen+L.bar+L.text+L.stride*slot,worker.n.menu_text_tab)
            if not okay or intact~=true then return false,'Waiting for native HUD+ tab ownership'end
        end
        if snapshot.count>=L.capacity then return false,'Native tab bar is full'end
        -- A late MOM installation must be bridged before it sees our fourth slot.
        if rawget(env,'ModOptionsMenu')and not rawget(env,'ModOptionsMenu').mcm_compat and not bridge then return false,'Waiting for cooperative MODS tab owner'end
        if bridge and snapshot.count==3 then return false,'Waiting for native MODS tab registration'end
        local labels=copy(snapshot.labels);labels[#labels+1]=L.template
        backend.apply_tabs(screen,labels,snapshot.current);backend.show_text(screen,snapshot.count)
        record={screen=screen,index=snapshot.count,labels=copy(snapshot.labels),previous=snapshot.current,previous_shown=snapshot.shown}
        return true
    end
    local function install_bridge()
        if bridge then return true end
        local step,slot,original,scan=mom_step(env,options.mom_step)
        last_mom_detail=scan
        if not step then
            local message=string.format('MODS owner scan: state=%s nodes=%d limit=%d exhausted=%s candidates=%d bar=%s tab=%s step_state=%s ensure_state=%s src=%q upvalues=%q ensure_src=%q ensure_upvalues=%q',tostring(scan.state),scan.nodes,scan.node_limit,tostring(scan.budget_exhausted),scan.candidates,tostring(scan.bar),tostring(scan.tab),tostring(scan.step_state),tostring(scan.ensure_state),scan.candidate_short_src or '',scan.candidate_upvalues or '',scan.ensure_short_src or '',scan.ensure_upvalues or '')
            if message~=last_mom_scan then last_mom_scan=message;if options.log then options.log('MCM native entry: '..message)end end
            return false
        end
        local hook
        hook=function(screen,...)
            if retired then return original(screen,...)end
            -- HUD before() may hide its selected final tab. With no MCM slot
            -- there is nothing to mask, and MOM handles that transient itself.
            if not record then return original(screen,...)end
            local snapshot=backend.snapshot(screen)
            if record and record.screen==screen and record.index==3 then
                local ok,why=remove();assert(ok,why);snapshot=backend.snapshot(screen)
            end
            local total=snapshot.count;local masked=total>4 and own(screen,snapshot)
            if masked then backend.set_count(screen,4)end
            local result=pack(pcall(original,screen,...))
            if masked then backend.set_count(screen,total)end
            if not result[1]then error(result[2],0)end
            return unpack(result,2,result.n)
        end
        debug.setupvalue(step,slot,hook);bridge={step=step,slot=slot,original=original,hook=hook}
        if options.log then options.log('MCM native entry: authenticated MODS owner linked (nodes='..scan.nodes..')')end
        return true
    end
    local function release_hud_bridge()
        if not hud_bridge then return end
        hud_bridge.active=false
        if rawget(hud_bridge.instance,'place')==hud_bridge.hook then rawset(hud_bridge.instance,'place',hud_bridge.raw_original)end
        if hud_bridge.show_hook and rawget(hud_bridge.instance,'show_tab')==hud_bridge.show_hook then rawset(hud_bridge.instance,'show_tab',hud_bridge.raw_show)end
        hud_bridge=nil
    end
    local function install_hud_bridge()
        if type(options.hud_menu)~='function'then hud_wait=false;return end
        local instance,initializing=options.hud_menu()
        hud_wait=initializing==true or instance~=nil
        if hud_bridge and hud_bridge.instance==instance then return end
        release_hud_bridge()
        if type(instance)~='table'or type(instance.n)~='table'then return end
        local n=instance.n
        if n.menu_tab_bar~=L.bar or n.menu_tab_count~=L.count or n.menu_tab_stride~=L.stride then return end
        local original=instance.place;if type(original)~='function'then return end
        local state={instance=instance,original=original,raw_original=rawget(instance,'place'),active=true}
        local show=instance.show_tab
        if type(show)=='function'then
            state.raw_show=rawget(instance,'show_tab')
            state.show_hook=function(worker,screen,shown)
                local slot=worker.slot
                if not retired and state.active and shown==false and record and record.screen==screen and type(slot)=='number'and slot%1==0 and slot>record.index and slot<L.capacity and type(worker.label_is)=='function'then
                    local snapshot=backend.snapshot(screen)
                    if own(screen,snapshot)and slot<snapshot.count and snapshot.labels[slot+1]==n.menu_text_tab then
                        local okay,intact=pcall(worker.label_is,worker,screen+L.bar+L.text+L.stride*slot,n.menu_text_tab)
                        if okay and intact==true then return end -- Keep a selected later HUD slot inside the visible count.
                    end
                end
                return show(worker,screen,shown)
            end
            rawset(instance,'show_tab',state.show_hook)
        end
        state.hook=function(worker,screen,...)
            if retired or not state.active then return original(worker,screen,...)end
            local snapshot=record and backend.snapshot(screen)or nil;local slot=worker.slot
            local masked=false
            if record and record.screen==screen and own(screen,snapshot)and type(slot)=='number'and slot%1==0 and slot>=3 and slot<record.index and snapshot.count>slot+1 and type(worker.label_is)=='function'then
                local okay,intact=pcall(worker.label_is,worker,screen+L.bar+L.text+L.stride*slot,n.menu_text_tab)
                masked=okay and intact==true
            end
            if masked then backend.set_count(screen,slot+1)end
            local result=pack(pcall(original,worker,screen,...))
            if masked then backend.set_count(screen,snapshot.count)end
            if not result[1]then error(result[2],0)end
            if result[2]==true and state.active and not retired and not retiring and not record then
                -- First publication happens after real HUD.place() restored its
                -- full count, never during its before()/Game-update hiding pass.
                state.after_place=true
                local worked,okay,why=pcall(self.step)
                state.after_place=false
                if not worked then note(okay)elseif okay==false then note(why)end
            end
            return unpack(result,2,result.n)
        end
        rawset(instance,'place',state.hook);hud_bridge=state
    end
    local function focused()return type(options.focused)=='function'and options.focused()==true end
    local function flags()
        local window=options.window;if not window then return end
        local result={focus=window.mouse_focus(),cursor=window.show_cursor(),clip=window.clip_cursor()}
        if type(result.focus)=='boolean'and type(result.cursor)=='boolean'and type(result.clip)=='boolean'then return result end
    end
    local function make_parent(screen,snapshot)
        local result={screen=screen,index=record.index,previous_index=record.previous,
            restoration_snapshot=flags(),gameplay_snapshot=copy(gameplay),active=true}
        function result.status()
            local current,status,current_snapshot=observed()
            local replaced=status=='open'and current~=screen
            return {open=status=='open'and current==screen,closed=status=='closed',covered=status=='covered'or replaced,replaced=replaced,
                current_owned=status=='open'and current==screen and current_snapshot.current==result.index and own(current,current_snapshot)or false}
        end
        function result.validate()
            local status=result.status()
            return result.active and focused()and status.open and status.current_owned and result.restoration_snapshot~=nil and gameplay~=nil
        end
        function result.on_close()
            local current,status,current_snapshot=observed()
            if status=='open'and current==screen and own(current,current_snapshot)and current_snapshot.current==result.index then
                backend.restore_selection(screen,record.previous,record.previous_shown)
            elseif status=='covered'or(status=='open'and current~=screen)then return false,'Native Escape is covered or replaced; close pending'end
            result.active=false;if parent==result then parent=nil end;return true
        end
        return result
    end
    function self.step()
        if retired then return end
        if retiring then return false,'Native entry cleanup pending'end
        local valid,why=initialize();if not valid then return false,why end
        install_bridge()
        install_hud_bridge()
        local screen,status=backend.escape_menu()
        local transition=status..'/mods='..tostring(bridge~=nil)..'/hud='..tostring(hud_bridge~=nil)..'/slot='..tostring(hud_bridge and hud_bridge.instance.slot)
        if transition~=last_state then last_state=transition;if options.log then options.log('MCM native entry: '..transition)end end
        if status=='closed'then
            record=nil;parent=nil
            if focused()and not(api.is_open and api.is_open())then local current=flags();if current and current.focus and not current.cursor then gameplay=current end end
            return true
        end
        if status~='open'then return true end
        if parent and api.is_open and not api.is_open()then
            local input=api.input_status and api.input_status()
            if not input or not(input.active or input.pending_restore or input.owner)then parent.active=false;parent=nil end
        end
        if record and record.screen~=screen then record=nil;parent=nil end
        if hud_wait and not record and not(hud_bridge and hud_bridge.after_place)then return false,'Waiting for native HUD+ tab placement'end
        local snapshot=backend.snapshot(screen)
        local ok,reason=publish(screen,snapshot);if not ok then note(reason);return false,reason end
        snapshot=backend.snapshot(screen)
        local selection=snapshot.current..'/'..record.index..'/focused='..tostring(focused())..'/baseline='..tostring(gameplay~=nil)..'/open='..tostring(api.is_open and api.is_open())
        if selection~=last_selection then last_selection=selection;if options.log then options.log('MCM native entry: selection='..selection)end end
        if not record.logged and own(screen,snapshot)then
            record.logged=true;note('Added owned native MCM tab: index='..record.index..' count='..snapshot.count)
        end
        if focused()and snapshot.current==record.index and not parent and not(api.is_open and api.is_open())then
            if not gameplay then note('Waiting for a verified gameplay cursor baseline');return false,'Gameplay cursor baseline unavailable'end
            local owner=make_parent(screen,snapshot)
            if not owner.validate()then note('Native MCM parent validation failed');return false,'Native MCM parent validation failed'end
            if type(options.on_open)~='function'then return false,'Native MCM open callback unavailable'end
            local opened,reason=options.on_open(owner)
            if opened~=true then note(reason or 'Native MCM opening refused');return false,reason or 'Native MCM opening refused'end
            parent=owner
            if options.log then options.log('MCM opened from native Escape entry')end
        end
        return true
    end
    function self.status()
        return {verified=verified==true,installed=wrapper~=nil,retired=retired==true,retiring=retiring==true,index=record and record.index,gameplay_baseline=gameplay~=nil,parent=parent,reason=last_reason,mom_scan=last_mom_detail}
    end
    function self.close()
        retiring=true
        if parent then local ok,why=parent.on_close();if not ok then return false,why end end
        if verified then local ok,why=remove();if not ok then return false,why end end
        retired=true
        release_hud_bridge()
        if bridge then local current=select(2,debug.getupvalue(bridge.step,bridge.slot));if current==bridge.hook then debug.setupvalue(bridge.step,bridge.slot,bridge.original)end;bridge=nil end
        if wrapper and rawget(env,'update')==wrapper then rawset(env,'update',previous)end
        return true
    end
    function self.install(ctx)
        if wrapper or retired then return false,'Native entry is already installed or retired'end
        local valid,why=initialize();if not valid then return false,why end
        previous=rawget(env,'update');if type(previous)~='function'then return false,'Game update callback unavailable'end
        wrapper=function(...)
            if not retired then local ok,why=pcall(self.step);if not ok then note(why)end end
            return previous(...)
        end
        rawset(env,'update',wrapper)
        if ctx and ctx.on_cleanup then ctx.on_cleanup(self.close)end
        return true
    end
    return self
end
return N
