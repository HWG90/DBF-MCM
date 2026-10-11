-- Real console surface/model with injected command and file services only.
local Console=assert(loadfile('src/console.lua'))()
local passed=0
local function test(name,fn)local ok,why=pcall(fn);assert(ok,name..': '..tostring(why));passed=passed+1;print('PASS '..name)end
local function fixture(bus,options)
    local model=Console.new({clock=function()return 0,'12:00:00'end});model.commands=bus
    local surface=Console.surface(model,options);local keys={};local pointer={x=-1,y=-1}
    local input={down=function(key)return keys[key]or false end,mouse=function()return pointer.x,pointer.y end,wheel=function()return pointer.wheel or 0 end}
    local function tick(dt)return surface.filter(input,true,dt or 0)end
    local function press(key)keys[key]=true;local filtered=tick();keys[key]=false;tick();return filtered end
    tick();surface.focus();tick();surface.compose(1920,1080,{x=800,y=400,w=400,h=400},true)
    return model,surface,keys,input,tick,press,pointer
end

test('Tab and Enter complete visible suggestions without executing commands',function()
    local calls,gets=0,0;local bus={suggest=function(text)return {{text='mod.enabled = true',label='Enable mod'},{text='mod.enabled = false',label='Disable mod'}}end,
        execute=function(command)calls=calls+1;assert(command=='mod.enabled = false');return true,'Saved'end,
        get=function()gets=gets+1;error('completion must not read settings')end}
    local model,surface,_,_,_,press=fixture(bus)
    model.window.command_text='mod.e';assert(#surface.command_state().suggestions==2)
    press(40);assert(surface.command_state().selected==2);press(9)
    assert(surface.command_state().text=='mod.enabled = false'and #surface.command_state().suggestions==0 and calls==0 and gets==0)
    press(13);assert(calls==1 and surface.command_state().text==''and model.window.command_history[1]=='mod.enabled = false')
    model.window.command_text='mod.e';press(40);press(13)
    assert(calls==1 and surface.command_state().text=='mod.enabled = false','first Enter accepts the suggestion')
    press(13);assert(calls==2 and gets==0)
end)

test('suggestions are bounded validated snapshots without item accessors',function()
    local values={};for index=1,90 do values[index]={text='value'..index,label='Choice '..index}end
    local source_calls=0;local model,surface=fixture({suggest=function()source_calls=source_calls+1;return values end})
    model.window.command_text='v';local first=surface.command_state();assert(#first.suggestions==64)
    first.suggestions[1].text='mutated';first.suggestions[1].label='mutated';first.selected=20
    values[1].text='provider changed';assert(surface.command_state().suggestions[1].text=='value1'and surface.command_state().selected==1 and source_calls==1)
    model.commands={suggest=function()return {{text='safe',label='Safe'},{text='bad\nvalue',label='Bad'},{text='good',label=3},setmetatable({},{__index=function()error('accessor called')end})}end}
    local snapshot=surface.command_state();assert(#snapshot.suggestions==1 and snapshot.suggestions[1].text=='safe')
end)

test('provider suggestion and execution failures remain within the console',function()
    local model,surface,_,_,_,press=fixture({suggest=function()error('suggest failed')end,execute=function()error('execute failed')end})
    model.window.command_text='typed';assert(#surface.command_state().suggestions==0)
    press(13);assert(surface.command_state().text==''and model.window.command_history[1]=='typed')
    local events=model.read();assert(#events==2 and events[2].severity=='error'and events[2].message:find('execute failed',1,true))
    model.commands=nil;model.window.command_text='missing';local ok,why=surface.submit();assert(not ok and why=='Console command service unavailable')
end)

test('Escape dismisses suggestions before leaving command editing',function()
    local model,surface,_,_,_,press=fixture({suggest=function()return {{text='help',label='Help'}}end})
    model.window.command_text='he';assert(#surface.command_state().suggestions==1)
    press(27);assert(surface.command_state().editing and #surface.command_state().suggestions==0 and model.window.visible)
    press(27);assert(not surface.command_state().editing and model.window.visible)
end)

test('typing owns Delete F10 modifiers and all keyboard keys; idle closed owns none',function()
    local model,surface,keys,input,tick,press=fixture({suggest=function()return {}end})
    press(65);press(66);assert(surface.command_state().text=='ab')
    keys[46]=true;keys[121]=true;keys[16]=true;keys[255]=true
    local filtered=tick();assert(not filtered.down(46)and not filtered.down(121)and not filtered.down(16)and not filtered.down(255))
    assert(surface.command_state().text=='','Delete clears command input')
    keys[46]=false;keys[121]=false;keys[16]=false;keys[255]=false;tick()
    model.window.visible=false;keys[46]=true;keys[121]=true;keys[192]=false
    filtered=tick();assert(filtered.down(46)and filtered.down(121))
    keys[192]=true;filtered=surface.filter(input,false);assert(filtered.down(192)and not model.window.visible)
end)

test('held typing repeats while opening and handoff drain held keys',function()
    local model,surface,keys,input,tick=fixture({suggest=function()return {}end})
    keys[65]=true;tick();assert(surface.command_state().text=='a')
    for _=1,5 do tick(.1)end;assert(#surface.command_state().text>1)
    local text=surface.command_state().text;local replacement=Console.surface(model);replacement.focus();replacement.filter(input,true,.1)
    assert(model.window.command_text==text,'held character across focus must not be replayed')
    surface.release();assert(model.window.input_focused,'former surface cannot release its successor focus')
    keys[65]=false;replacement.filter(input,true,.1);keys[66]=true;replacement.filter(input,true,.1)
    assert(model.window.command_text==text..'b')
    replacement.release();assert(not model.window.input_focused and not model.window.focused)
end)

test('command history stays ordered bounded and navigable',function()
    local model,surface,_,_,_,press=fixture({suggest=function()return {}end,execute=function()return true,'done'end})
    for index=1,55 do model.window.command_text='command'..index;assert(surface.submit())end
    assert(#model.window.command_history==50 and model.window.command_history[1]=='command6')
    press(38);assert(surface.command_state().text=='command55');press(38);assert(surface.command_state().text=='command54')
    press(40);assert(surface.command_state().text=='command55');press(40);assert(surface.command_state().text=='')
    model.window.command_text='help';model.commands.execute=function()return true,'First line\nSecond line'end;assert(surface.submit())
    local events=model.read();assert(events[#events-1].message=='First line'and events[#events].message=='Second line')
end)

test('UTF-8 backspace and visible tail never split multibyte characters',function()
    local model,surface,_,_,_,press=fixture({suggest=function()return {}end})
    local accent='\195\169';local face='\240\159\152\128'
    model.window.command_text='a'..face..accent;press(8);assert(surface.command_state().text=='a'..face)
    press(8);assert(surface.command_state().text=='a');press(8);assert(surface.command_state().text=='')
    model.window.command_text=string.rep(face,250)..accent
    local tail_seen=false
    for _,command in ipairs(surface.compose(1920,1080,nil,true))do
        if command.type=='text'and command.text:sub(-#accent-1)==accent..'|'then
            tail_seen=true;assert(command.text:sub(1,#face)==face and #command.text<#model.window.command_text)
            local body=command.text:sub(1,-2);local rest=body:gsub(face,''):gsub(accent,'');assert(rest=='')
        end
    end
    assert(tail_seen)
end)

test('popup suggestions use higher layers while default console keeps layer 400',function()
    local custom={17,18,19};local model,surface=fixture({suggest=function()return {{text='help',label='Help'}}end},{palette={background=custom},toggle_key=120})
    local commands=surface.compose(1920,1080,nil,true);assert(commands[1].c==custom)
    for _,command in ipairs(commands)do assert(command.layer==400)end
    model.window.command_text='h';commands=surface.compose(1920,1080,nil,true)
    local popup=false;for _,command in ipairs(commands)do if command.layer==414 then popup=true end end;assert(popup)
    local _,alternate,_,_,_,press=fixture(nil,{toggle_key=120});press(120);assert(not alternate.command_state().editing)
end)

test('dragging resize and docking retain their existing geometry contracts',function()
    local model,surface,keys,_,tick,_,pointer=fixture(nil)
    local initial=surface.bounds;pointer.x=initial.x+20;pointer.y=initial.y+initial.h-20;keys[1]=true;tick();assert(model.window.drag)
    pointer.x=pointer.x+50;pointer.y=pointer.y+40;tick();assert(model.window.x==initial.x+50 and model.window.y==initial.y+40)
    keys[1]=false;tick();assert(not model.window.drag)
    surface.compose(1920,1080,{x=800,y=400,w=400,h=400},true);assert(surface.dock('left'));assert(not surface.dock('right'))
    surface.dock('free');surface.compose(1920,1080,nil,true);local resized=surface.bounds
    pointer.x=resized.x+resized.w-2;pointer.y=resized.y+resized.h/2;keys[1]=true;tick();assert(model.window.resize)
    pointer.x=pointer.x+30;tick();assert(model.window.width>740);keys[1]=false;tick();assert(not model.window.resize)
end)

test('owner logger appends only safe IDs and closes the injected file',function()
    local calls,writes,closes={},{},0;local file={write=function(_,value)writes[#writes+1]=value;return true end,close=function()closes=closes+1;return true end}
    local sink=Console.owner_logger('existing/logs',{open=function(path,mode)calls[#calls+1]={path,mode};return file end,clock=function()return 0,'12:34:56'end})
    local ok,path=sink('mod-id_1','bad\nmessage','error');assert(ok and path=='existing/logs/MCM-mod-id_1.log')
    assert(calls[1][2]=='a'and writes[1]=='12:34:56 ERROR bad message\n'and closes==1)
    assert(sink('mod-id_1','registered','debug')and #calls==2)
    for _,owner in ipairs({'../escape','a/b','a\\b','',string.rep('x',81)})do assert(not sink(owner,'message','info'))end
    assert(not sink(123,'message','info')and #calls==2)
    local slash=Console.owner_logger('existing/logs/',{open=function(path,mode)assert(path=='existing/logs/MCM-owner.log'and mode=='a');return file end,clock=function()return 'now'end})
    assert(slash('owner','message','info'))
end)

test('owner logger reports open write close and clock failures without throwing',function()
    local function sink(options)return Console.owner_logger('logs',options)end
    local ok,why=sink({open=function()return nil,'open denied'end})('owner','message');assert(not ok and why=='open denied')
    ok,why=sink({open=function()error('open threw')end})('owner','message');assert(not ok and tostring(why):find('open threw',1,true))
    local closed=false;ok,why=sink({open=function()return {write=function()return nil,'disk full'end,close=function()closed=true;return true end}end})('owner','message')
    assert(not ok and why=='disk full'and closed)
    ok,why=sink({open=function()return {write=function()return true end,close=function()return nil,'close denied'end}end})('owner','message');assert(not ok and why=='close denied')
    closed=false;ok,why=sink({open=function()return {write=function()error('must not write')end,close=function()closed=true;return true end}end,clock=function()error('clock failed')end})('owner','message')
    assert(not ok and tostring(why):find('clock failed',1,true)and closed)
end)
local function memory_logs(contents)
    local calls={open=0,read=0,close=0,max_read=0};local seen={}
    local function open(path,mode)
        calls.open=calls.open+1;seen[path]=true;assert(mode=='rb')
        if not contents[path]then return nil,'missing'end
        local cursor=0
        return {seek=function(_,mode,offset)
            if mode=='end'then cursor=#contents[path]+offset elseif mode=='set'then cursor=offset else error('Unexpected seek mode')end
            return cursor
        end,read=function(_,count)
            calls.read=calls.read+1;calls.max_read=math.max(calls.max_read,count)
            local value=contents[path]:sub(cursor+1,cursor+count);cursor=cursor+#value;return value
        end,close=function()calls.close=calls.close+1;return true end}
    end
    return open,calls,seen
end
test('known log follower seeds EOF throttles and emits only new owned errors',function()
    local contents={['logs/source.log']='ERROR old event\n'};local open,calls=memory_logs(contents)
    local model=Console.new({clock=function()return 0,'now'end})
    local follower=Console.follow_logs(model,{paths={Source='logs/source.log'},open=open})
    assert(follower.tick(.25)==0 and calls.open==0);assert(follower.tick(.25)==0 and calls.read==0)
    contents['logs/source.log']=contents['logs/source.log']..'INFO fine\nERROR new event\noperation failed\nexception caught\n'
    local events,bytes=follower.tick(.5);assert(events==3 and bytes>0 and model.count==3 and calls.open==calls.close)
    for _,event in ipairs(model.read())do assert(event.source=='Source'and event.severity=='error'and event.log_path=='logs/source.log'and not event.message:find('old event',1,true))end
    assert(follower.tick(.5)==0 and model.count==3);follower.release();local before=calls.open;assert(follower.tick(1)==0 and calls.open==before)
end)
test('log follower resumes bounded chunks partial lines and truncation',function()
    local contents={['a.log']='ERROR split message\nINFO fine\nERROR next\n'};local open,calls=memory_logs(contents)
    local model=Console.new({clock=function()return 0,'now'end})
    local follower=Console.follow_logs(model,{paths={Owner='a.log'},open=open,read_existing=true,max_bytes=7})
    for _=1,9 do local _,bytes=follower.tick(.5);assert(bytes<=7)end
    local events=model.read();assert(#events==2 and events[1].message=='ERROR split message'and events[2].message=='ERROR next'and calls.max_read<=7)
    contents['a.log']='ERROR reset\n';for _=1,3 do follower.tick(.5)end
    events=model.read();assert(#events==3 and events[3].message=='ERROR reset')
    contents['a.log']=contents['a.log']..'ERROR partial';for _=1,3 do follower.tick(.5)end;assert(model.count==3)
    contents['a.log']=contents['a.log']..' completed\n';for _=1,3 do follower.tick(.5)end
    assert(model.read()[4].message=='ERROR partial completed')
end)
test('log follower caps sources and total bytes tolerates file errors and preserves editing',function()
    local contents,paths={},{};for index=1,12 do local path=index..'.log';contents[path]='ERROR '..index..'\n';paths[string.format('Source%02d',index)]=path end
    paths.SourceDuplicate='1.log';local open,calls,seen=memory_logs(contents)
    local model,surface=fixture({suggest=function()return {}end});model.window.command_text='still typing'
    local follower=Console.follow_logs(model,{paths=function()return paths end,open=open,max_sources=100,read_existing=true,max_bytes=8})
    for _=1,20 do local _,bytes=follower.tick(.5);assert(bytes<=8)end
    assert(model.count==12 and seen['9.log']and calls.open<=160 and calls.max_read<=8 and surface.command_state().text=='still typing'and surface.command_state().editing)
    paths={Replacement='replacement.log'};contents['replacement.log']='ERROR replacement\n';for _=1,3 do follower.tick(.5)end;assert(model.read()[13].source=='Replacement')
    local broken=Console.follow_logs(model,{paths={Broken='bad.log'},open=function()return {seek=function()error('locked')end,close=function()return true end}end})
    assert(broken.tick(.5)==0 and surface.command_state().editing)
    local resolver=Console.follow_logs(model,{paths=function()error('paths unavailable')end,open=open});assert(resolver.tick(.5)==0)
end)
test('literal log discovery reads only known entry and declared modules with cached bounds',function()
    local sources={['mods/demo/main.lua']='local log="Demo.log"; local old="LiveLuaLoader.log"; local own="MCM-startup.log"',
        ['mods/demo/src/module.lua']='local error_log="Module.log"; local forged="../Out.log"'}
    local reads,opened={},{};local cache={}
    local function open(path,mode)
        opened[path]=true;assert(mode=='rb');if not sources[path]then return nil,'missing'end
        return {read=function(_,count)reads[#reads+1]=count;return sources[path]:sub(1,count)end,close=function()return true end}
    end
    local catalog={['live/demo']={id='demo',dir='mods/demo',path='mods/demo/main.lua',project={entry='main.lua',modules={'src/module.lua','../escape.lua','unsafe.txt'}}}}
    local options={open=open,cache=cache,max_files=4,max_file_bytes=1024,max_bytes=2048}
    local paths=Console.discover_logs(catalog,{'logs'},options);local found={}
    for owner,path in pairs(paths)do assert(owner:match('^[%w_-]+$')and #owner<=80);found[path]=true;assert(not path:find('LiveLuaLoader',1,true)and not path:find('MCM-',1,true)and not path:find('../',1,true))end
    assert(found['logs/Demo.log']and found['logs/Module.log']and found['mods/demo/Logs/Demo.log']and not opened['mods/escape.lua'])
    assert(opened['mods/demo/main.lua']and opened['mods/demo/src/module.lua']and not opened['mods/demo/unsafe.txt'])
    local before=#reads;Console.discover_logs(catalog,{'logs'},options);assert(#reads==before,'cached source literals do not reread')
    catalog['live/demo'].revision=2;Console.discover_logs(catalog,{'logs'},options);assert(#reads>before)
end)
test('explicit log metadata stays within entry or allowed roots and ambiguous owners are omitted',function()
    local catalog={
        {id='first',path='C:/mods/first/main.lua',dir='C:/mods/first',metadata={log_files={'Logs/Own.log','C:/allowed/Absolute.log','C:/outside/Escape.log','../escape.log','setting.ini','MCM-first.log'}}},
        {id='second',path='C:/mods/second/main.lua',dir='C:/mods/second'},
        {id='../bad',path='C:/mods/bad/main.lua',dir='C:/mods/bad'},
    }
    local source={['C:/mods/first/main.lua']='local log="Shared.log"',['C:/mods/second/main.lua']='local log="Shared.log"'}
    local function open(path)return source[path]and {read=function()return source[path]end,close=function()return true end}or nil end
    local result=Console.discover_logs(catalog,{'C:/allowed'},{open=open});local found={}
    for owner,path in pairs(result)do found[path]=true;assert(owner:match('^[%w_-]+$')and not path:find('outside',1,true)and not path:find('escape',1,true)and not path:find('%.ini$'))end
    assert(found['C:/mods/first/Logs/Own.log']and found['C:/allowed/Absolute.log'])
    assert(not found['C:/allowed/Shared.log'],'a shared literal cannot attribute one file to two owners')
    assert(found['C:/mods/first/Shared.log']and found['C:/mods/second/Shared.log'])
end)
test('discovery honors global read file candidate caps without scanning directories',function()
    local catalog={};for index=1,12 do catalog[index]={id='owner'..index,dir='mods/'..index,path='mods/'..index..'/main.lua'}end
    local opened,read_bytes=0,0
    local function open(path,mode)opened=opened+1;assert(mode=='rb');return {read=function(_,count)read_bytes=read_bytes+count;return ('local a="One.log"; local b="Two.log"'):rep(4):sub(1,count)end,close=function()return true end}end
    local result=Console.discover_logs(catalog,{'logs'},{open=open,max_files=2,max_bytes=70,max_file_bytes=40,max_logs=3})
    local count=0;for _ in pairs(result)do count=count+1 end;assert(opened<=2 and read_bytes<=70 and count<=3)
end)
test('boolean project catalogs discover module-owned logs through only their known manifest',function()
    local files={['mods/actual/main.lua']='return mod.require("src.module")',
        ['mods/actual/manifest.json']='{"lll":{"entry":"main.lua","modules":["src/module.lua","../private.lua","bad.txt","C:/outside.lua"]},"unrelated":"not_declared.lua"}',
        ['mods/actual/src/module.lua']='local own_log="ModuleOwned.log"; return {}'}
    local opened,counts,bytes={},0,0;local cache={}
    local function open(path,mode)
        opened[path]=true;counts=counts+1;assert(mode=='rb');if not files[path]then return nil,'missing'end
        return {read=function(_,count)local value=files[path]:sub(1,count);bytes=bytes+#value;return value end,close=function()return true end}
    end
    local catalog={['live/actual']={id='actual',project=true,dir='mods/actual',path='mods/actual/main.lua'}}
    local result=Console.discover_logs(catalog,{'logs'},{open=open,cache=cache,max_files=4,max_bytes=1024,max_file_bytes=512})
    local found=false;for _,path in pairs(result)do if path=='logs/ModuleOwned.log'then found=true end end
    assert(found and opened['mods/actual/manifest.json']and opened['mods/actual/src/module.lua']and counts==3 and bytes<=1024)
    assert(not opened['mods/private.lua']and not opened['mods/actual/bad.txt']and not opened['C:/outside.lua']and not opened['mods/actual/not_declared.lua'])
    Console.discover_logs(catalog,{'logs'},{open=open,cache=cache,max_files=4,max_bytes=1024,max_file_bytes=512});assert(counts==3,'known manifest and module literals share the discovery cache')
end)
test('discovered paths retain exact original catalog keys without ambiguous host attribution',function()
    local catalog={
        ['live/shared']={id='shared',dir='mods/live',path='mods/live/main.lua',project={modules={}}},
        ['mdl/shared']={id='shared',dir='mods/mdl',path='mods/mdl/mod.lua',project={modules={}}},
    }
    local function open(path)return {read=function()return 'local log="Owned.log"'end,close=function()return true end}end
    local paths,source_keys=Console.discover_logs(catalog,{'logs'},{open=open})
    local live,mdl,ambiguous=false,false,false
    for key,path in pairs(paths)do
        if path:match('^mods/live/')then assert(source_keys[key]=='live/shared');live=true
        elseif path:match('^mods/mdl/')then assert(source_keys[key]=='mdl/shared');mdl=true
        elseif path=='logs/Owned.log'then assert(source_keys[key]==nil);ambiguous=true end
    end
    assert(live and mdl and ambiguous)
    local array={{id='array_owner',dir='mods/array',path='mods/array/main.lua',project={modules={}}}}
    paths,source_keys=Console.discover_logs(array,{}, {open=open})
    for key in pairs(paths)do assert(source_keys[key]==1,'array catalog keys remain numeric and exact')end
end)
print('PASS '..passed..' console command and logger contracts')
