-- Integration with the maintained LLL diagnostics/command providers, no game.
local root=os.getenv('MCM_LLL_TEST_ROOT')or'../DBF-Suite/LLL'
LLL_UI_THEME=dofile(root..'/src/ui/theme.lua')
LLL_UI_TEXT=dofile(root..'/src/ui/text.lua')
LLL_METADATA=dofile(root..'/src/metadata.lua')
local HostConsole=dofile(root..'/src/ui/diagnostics.lua')
local HostCommands=dofile(root..'/src/commands.lua')
local Console=dofile('src/console.lua');local Commands=dofile('src/commands.lua')
local Core=dofile('src/core.lua');local Menu=dofile('src/menu.lua')
local passed=0
local function test(name,fn)local ok,why=pcall(fn);assert(ok,name..': '..tostring(why));passed=passed+1;print('PASS '..name)end
local function fixture()
    local model=HostConsole.new();local surface=Console.surface(model,{explicit_open=true})
    local keys={};local input={down=function(key)return keys[key]or false end,mouse=function()end,wheel=function()return 0 end}
    local function tick(open)return surface.filter(input,open~=false,0)end
    local function press(key)keys[key]=true;tick();keys[key]=false;tick()end
    return model,surface,keys,input,tick,press
end
test('LLL startup errors stay recorded without opening or stealing MCM input',function()
    local model,surface,keys,_,tick=fixture()
    model.record('LLL','startup failed','error');assert(model.window.visible)
    keys[9]=true;keys[46]=true;local filtered=tick()
    assert(filtered.down(9)and filtered.down(46))
    assert(#surface.compose(1920,1080,nil,true)==0 and not surface.command_state().editing)
    assert(model.count==1 and model.read()[1].source=='LLL'and model.window.visible)
end)
test('explicit open works; a later LLL error cannot reopen a closed MCM console',function()
    local model,surface,_,_,tick,press=fixture();tick();surface.focus();tick()
    assert(#surface.compose(1920,1080,nil,true)>0 and surface.command_state().editing)
    press(192);assert(not model.window.visible)
    model.record('Other mod','update failed','error');assert(model.window.visible)
    assert(#surface.compose(1920,1080,nil,true)==0 and not surface.command_state().editing)
    press(192);assert(#surface.compose(1920,1080,nil,true)>0)
end)
test('parent close resets MCM visibility without clearing LLL history or geometry',function()
    local model,surface,_,_,tick=fixture();tick();surface.focus();tick()
    model.window.command_text='draft';model.window.width=800;model.record('LLL','retained')
    surface.compose(1920,1080,nil,true);tick(false);tick()
    assert(#surface.compose(1920,1080,nil,true)==0)
    assert(model.window.visible and model.window.command_text=='draft'and model.window.width==800 and model.count==1)
end)
test('the hosted diagnostics provider takes precedence over a stale cached provider',function()
    local previous=rawget(_G,'DBFDiagnostics');local cached=package.loaded['dbf.diagnostics.v1']
    local old=Console.new();rawset(_G,'DBFDiagnostics',old);package.loaded['dbf.diagnostics.v1']=old
    local hosted=HostConsole.new();assert(Console.shared(hosted)==hosted)
    assert(rawget(_G,'DBFDiagnostics')==hosted and package.loaded['dbf.diagnostics.v1']==hosted)
    rawset(_G,'DBFDiagnostics',previous);package.loaded['dbf.diagnostics.v1']=cached
end)
test('MCM uses LLL registrations for suggestions and owner setters',function()
    local bus=HostCommands.new();local value=2;local owner={console_active=true}
    local release=bus.register('probe',owner,{value={type='number',get=function()return value end,set=function(v)value=v;return true end}})
    local model,surface,_,_,tick=fixture();local api=Core.new()
    local loader={console=bus,diagnostics=model};model.commands=Commands.for_host(api,loader,model)
    assert(model.commands==bus);tick();surface.focus();tick();model.window.command_text='probe.v'
    local suggestions=surface.command_state().suggestions;assert(#suggestions>0 and suggestions[1].text:find('probe.value',1,true))
    model.window.command_text='probe.value = 7';assert(surface.submit()and value==7)
    loader.console=nil;assert(Commands.for_host(api,loader,model)==bus)
    assert(Commands.for_host(api,nil,model)~=bus,'retired hosted bus must not leak into standalone reload')
    release();assert(#bus.suggest('probe.v')==0)
end)
test('MCM opens only from its Console action and stays closed on the next menu opening',function()
    local model=HostConsole.new();model.record('LLL','initialization failed','error')
    local api=Core.new();api.diagnostics=model;api.diagnostics_surface=Console.surface
    api.register({id='host_test',name='Test',pages={{id='main',name='Main',controls={{id='enabled',type='toggle',label='Enabled',default=true}}}}})
    local menu=Menu.new(api);menu.visible=true
    local function has_console()for _,c in ipairs(menu.compose(1920,1080))do if c.diagnostic_console then return true end end;return false end
    assert(not has_console());assert(menu.open_console()and has_console())
    menu.visible=false;menu.compose(1920,1080);menu.visible=true;assert(not has_console())
    assert(model.count==1 and model.read()[1].severity=='error')
end)
print('PASS '..passed..' hosted console contracts')
