local module=assert(loadfile('src/console.lua'))()
local now=0
local d=module.new({capacity=16,clock=function()now=now+1;return now,'12:00:00'end})
local a=d.attach('MCM','real.log');local b=d.attach('LLL')
d.record('MCM','Failure','error','actual details')
d.record('MCM','Failure','error','actual details')
assert(d.count==1 and d.read()[1].repeats==2 and d.read()[1].log_path=='real.log')
local copy=d.read();copy[1].message='changed';assert(d.read()[1].message=='Failure')
for i=1,30 do d.record('LLL','Event '..i)end
assert(d.count==16 and d.read()[1].message=='Event 15')
local surface=module.surface(d);local keys={};local x,y=0,0
local input={down=function(k)return keys[k]or false end,mouse=function()return x,y end,wheel=function()return 0 end}
surface.filter(input,true);keys[192]=true;surface.filter(input,true)
assert(d.window.visible)
surface.filter(input,true);assert(d.window.visible)
local commands=surface.compose(1920,1080,{x=800,y=400,w=400,h=400},true)
assert(#commands>0 and #commands<100)
for _,c in ipairs(commands)do assert(c.diagnostic_console and c.popup and c.layer==400)end
surface.release();local second=module.surface(d);second.filter(input,true)
assert(d.window.visible) -- held hotkey across handoff must not retoggle
second.compose(1920,1080,{x=800,y=400,w=400,h=400},true)
assert(second.dock('left'));assert(d.window.x>=0)
assert(not second.dock('right')) -- 740px cannot fit to the right
keys[192]=false;second.filter(input,false);keys[192]=true;second.filter(input,false)
assert(d.window.visible) -- closed menus cannot toggle
assert(d.detach(a) and d.window.visible);assert(d.detach(b) and not d.window.visible)
assert(not d.detach(b))
for _,name in ipairs({'adapter','startup','core','menu','view'})do assert(loadfile('src/'..name..'.lua'))end
local core=assert(loadfile('src/core.lua'))();local menu_module=assert(loadfile('src/menu.lua'))()
local events={};local api=core.new(nil,function(message)events[#events+1]=message end)
api.diagnostics=d;api.diagnostics_surface=module.surface
local handle=api.register({id='diagnostic_test',name='Test',pages={{id='main',name='Main',require_confirmation=false,controls={{id='label',type='input',label='Label',default='secret'}}}}})
assert(handle.set('label','private value'));assert(events[#events]=='Setting committed: diagnostic_test.label')
local m=menu_module.new(api);m.visible=true;keys[192]=false;m.tick(input);keys[192]=true;m.tick(input)
local drew=false;for _,c in ipairs(m.compose(1920,1080))do if c.diagnostic_console then drew=true end end
assert(drew);m.recover();assert(not m.visible)
print('Diagnostics contracts passed')
