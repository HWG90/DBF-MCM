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

test('hidden console does not repeatedly scan the keyboard',function()
 local model=Console.new();local surface=Console.surface(model,{explicit_open=true,toggle_key=false})
 local reads=0;local input={down=function()reads=reads+1;return false end,mouse=function()end}
 surface.filter(input,true,0);reads=0
 for _=1,1000 do surface.filter(input,true,0)end
 assert(reads<=1000,'Hidden console scanned non-mouse keys while idle')
end)

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
test('external log ingestion APIs are absent',function()
    assert(Console.discover_logs==nil and Console.host_logs==nil and Console.follow_logs==nil)
    assert(type(Console.new)=='function' and type(Console.owner_logger)=='function')
end)
print('PASS '..passed..' console command and logger contracts')
