-- Isolated contracts for the real core; no files, settings or native calls.
local Core=assert(loadfile('src/core.lua'))()
local Grouping=assert(loadfile('src/grouping.lua'))()
local passed=0
local function test(name,fn)local ok,why=pcall(fn);assert(ok,name..': '..tostring(why));passed=passed+1;print('PASS '..name)end
local function spec(owner)
    return {id=owner or 'owner',name=owner or 'Owner',pages={{id='general',name='General',controls={
        {id='flag',type='toggle',label='Flag',default=true},
        {id='other',type='toggle',label='Other',default=true},
        {id='run',type='button',label='Run',on_activate=function()return 'done'end},
        {type='text',label='Help'},
    }}}}
end
local function recording(options,store,grouping)
    local global,owned={},{};options=options or {}
    if not options.mod_log then options.mod_log=function(owner,message,level)owned[#owned+1]={id=owner,message=message,level=level};return true end end
    return Core.new(store,function(message)global[#global+1]=message end,grouping,options),global,owned
end
local function failing()error('owned callback failure')end

test('three-argument API preserves callback isolation and fallback diagnostics',function()
    local logs={};local called=0;local s=spec();s.pages[1].controls[1].on_change=failing
    s.on_change=function(value,key,old)assert(value==false and key=='flag'and old==true);called=called+1 end
    local h=Core.new(nil,function(message)logs[#logs+1]=message end).register(s)
    assert(h.set('flag',false)and h.get('flag')==false and called==1)
    assert(#logs==2 and logs[1]:find('Callback failed for owner.flag',1,true)and logs[2]=='Setting committed: owner.flag')
end)

test('registration errors keep safe candidate ownership and still raise',function()
    local api,global,owned=recording();local s=spec('broken');s.pages[1].controls[1].type='unknown'
    local ok,why=pcall(api.register,s)
    assert(not ok and tostring(why):find('Unsupported control',1,true)and not api.mods.broken and api.revision==0)
    assert(#global==0 and #owned==1 and owned[1].id=='broken'and owned[1].level=='error')
    assert(owned[1].message:find('Registration failed:',1,true))
    assert(not pcall(api.register,spec('../unsafe'))and #owned==1 and #global==1)
    assert(not pcall(api.register,spec(string.rep('x',81)))and #owned==1 and #global==2)
    local token={};local provider={load=function(owner)if owner~='mcm_custom_palette'then error(token)end;return {}end,save=function()return true end}
    local failed=spec('load_error');failed.storage=provider;ok,why=pcall(api.register,failed)
    assert(not ok and why==token and owned[2].id=='load_error','registration rethrows original error value')
end)

test('successful registration is quiet until runtime verbosity is enabled',function()
    local writes=0;local store={load=function()return {}end,save=function()writes=writes+1;return true end}
    local runtime=false;local api,global,owned=recording({verbose=function()return runtime end},store)
    assert(api.get_verbose()==false);api.register(spec('quiet'));assert(#owned==0 and #global==0)
    runtime=true;assert(api.get_verbose());api.register(spec('detailed'))
    assert(#owned==1 and owned[1].id=='detailed'and owned[1].level=='debug')
    assert(owned[1].message=='Registered mod: detailed (1 pages, 0 categories, 4 controls)')
    assert(api.set_verbose(false)==false);api.register(spec('quiet_again'));assert(not api.get_verbose()and #owned==1)
    assert(api.set_verbose(true)==true);api.register(spec('loud_again'));assert(#owned==2 and api.get_verbose())
    assert(not pcall(api.set_verbose,'yes')and writes==0,'verbosity is runtime-only')
    local predicate_error=recording({verbose=function()error('unavailable')end});assert(not predicate_error.get_verbose())
    predicate_error.register(spec('predicate_safe'))
    local enabled,_,events=recording({verbose=true});enabled.register(spec('bool_enabled'));assert(#events==1)
end)

test('set, page Apply and batch errors identify their mod and control',function()
    local saves,notifications={},{};local store={load=function()return {}end,save=function(owner,values)saves[#saves+1]={owner,values};return true end}
    local api,global,owned=recording(nil,store);local s=spec('source')
    s.pages[1].controls[1].on_change=failing;s.on_change=function(value,key,old)notifications[#notifications+1]={value,key,old}end
    local h=api.register(s)
    assert(h.set('flag',false));assert(#owned==1 and owned[1].id=='source'and owned[1].message:find('source.flag',1,true))
    h.edit('flag',true);assert(h.preview('flag')==true and h.get('flag')==false)
    assert(h.confirm('general')and h.get('flag')==true and next(api.mods.source.pages[1].pending)==nil)
    assert(h.set_many({flag=false,other=false})and h.get('other')==false)
    assert(#owned==3 and #saves==3 and #notifications==4 and #global==3)
    for _,event in ipairs(owned)do assert(event.id=='source'and event.level=='error'and event.message:find('source.flag',1,true))end
    for _,save in ipairs(saves)do assert(save[1]=='source')end
end)

test('failed saves remain uncommitted and reach the owning mod log',function()
    local callbacks=0;local store={load=function()return {}end,save=function()return false,'disk failure'end}
    local api,_,owned=recording(nil,store);local s=spec('save_owner');s.on_change=function()callbacks=callbacks+1 end
    local h=api.register(s);local ok,why=h.set('flag',false);assert(not ok and why=='disk failure'and h.get('flag')==true)
    h.edit('flag',false);ok,why=h.confirm('general');assert(not ok and why=='disk failure'and h.preview('flag')==false and h.get('flag')==true)
    ok,why=h.set_many({flag=false});assert(not ok and why=='disk failure'and h.get('flag')==true and callbacks==0)
    assert(#owned==3);for _,event in ipairs(owned)do assert(event.id=='save_owner'and event.level=='error'and event.message:find('disk failure',1,true))end
end)

test('validation and action errors retain their existing failure behavior',function()
    local api,global,owned=recording();local s=spec('callbacks');s.pages[1].controls[1].validate=failing;s.pages[1].controls[3].on_activate=failing
    local h=api.register(s);local ok,why=pcall(h.set,'flag',false)
    assert(not ok and tostring(why):find('owned callback failure',1,true)and h.get('flag')==true)
    ok,why=h.activate('run');assert(not ok and tostring(why):find('owned callback failure',1,true))
    assert(#global==0 and #owned==2 and owned[1].message:find('callbacks.flag',1,true)and owned[2].message:find('callbacks.run',1,true))
end)

test('presentation mounts and linked controls never own provider errors',function()
    local api,_,owned=recording(nil,nil,Grouping)
    local parent=spec('parent');parent.name='Presentation';parent.pages[1].controls={{id='alias',type='toggle',label='Alias',default=true,source_mod_id='linked_owner',source_control_id='flag'}};api.register(parent)
    local child=spec('child_owner');child.parent_name='Presentation';child.pages[1].controls[1].on_change=failing;api.register(child)
    local source=spec('linked_owner');source.pages[1].controls[1].on_change=failing;api.register(source)
    local presentation;for _,mod in ipairs(api.list())do if mod.id=='parent'then presentation=mod end end
    assert(presentation and presentation.handle.set('child_owner__flag',false)and presentation.handle.set('alias',false))
    assert(#owned==2 and owned[1].id=='child_owner'and owned[2].id=='linked_owner')
end)

test('sink exceptions and false results cannot break callbacks or registration',function()
    for _,sink in ipairs({function()error('sink failure')end,function()return false,'disk error'end})do
        local global={};local continued=false;local api=Core.new(nil,function(message)global[#global+1]=message end,nil,{mod_log=sink,verbose=true})
        local s=spec('sink_owner');s.pages[1].controls[1].on_change=failing;s.on_change=function()continued=true end
        local h=api.register(s);assert(h.set('flag',false)and continued and h.get('flag')==false)
        assert(#global==3 and global[1]:find('Registered mod:',1,true)and global[2]:find('Callback failed',1,true))
        local invalid=spec('sink_bad');invalid.pages={};local ok,why=pcall(api.register,invalid)
        assert(not ok and tostring(why):find('At least one page required',1,true)and not api.mods.sink_bad)
    end
    local s=spec();s.pages[1].controls[1].on_change=failing
    local h=Core.new(nil,function()error('legacy logger failure')end,nil,{mod_log=function()error('sink failure')end}).register(s)
    -- Existing successful transaction diagnostics still use the caller's legacy logger.
    local ok=pcall(h.activate,'run');assert(not ok)
    s=spec('both_fail');s.pages[1].controls[3].on_activate=failing
    h=Core.new(nil,function()error('legacy logger failure')end,nil,{mod_log=function()error('sink failure')end}).register(s)
    local success,why=h.activate('run');assert(not success and tostring(why):find('owned callback failure',1,true))
end)
print('PASS '..passed..' mod logging contracts')
