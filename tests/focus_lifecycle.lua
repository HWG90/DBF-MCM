local Core=dofile('src/core.lua');local Menu=dofile('src/menu.lua');local Capture=dofile('src/capture.lua')
local api=Core.new();api.mount=function()return false end
api.register({id='demo',name='Demo',pages={{id='general',name='General',require_confirmation=false,controls={{id='toggle',type='toggle',label='Toggle',default=false}}}}})
local menu=Menu.new(api);menu.visible=true;menu.focus='settings'
local focused=true;local keys={};local polls=0;local closes=0;local flags={focus=true,cursor=false,clip=true};local active=false
local native={mcm_install=function()return 1 end,mcm_capture=function()active=true;return 1 end,mcm_captured=function()return active and 1 or 0 end,mcm_release=function()active=false end}
local window={mouse_focus=function()return flags.focus end,show_cursor=function()return flags.cursor end,clip_cursor=function()return flags.clip end,set_mouse_focus=function(v)flags.focus=v end,set_show_cursor=function(v)flags.cursor=v end,set_clip_cursor=function(v)flags.clip=v end}
local capture=Capture.new(native,window,function()end)
local input={poll=function()polls=polls+1 end,focused=function()return focused end,window=function()return focused and 1 or nil end,down=function(k)return focused and keys[k]==true end,mouse=function()return nil end}
local file=assert(io.open('src/adapter.lua'));local source=file:read('*a');file:close();local adapter=assert(loadstring('local MCM=...\n'..source))({})
local function put(fn,wanted,value)
 for i=1,80 do local name=debug.getupvalue(fn,i);if not name then break end;if name==wanted then debug.setupvalue(fn,i,value);return end end
 error('Missing adapter upvalue: '..wanted)
end
put(adapter.on_update,'input',input);put(adapter.on_update,'api',api);put(adapter.on_update,'menu',menu);put(adapter.on_update,'capture',capture)
put(adapter.on_update,'legacy',{poll=function()end,diagnostic=function()return 'stable'end,release=function()end})
put(adapter.on_update,'diagnostic','stable');put(adapter.on_update,'view',{draw=function()end,release=function()end})
stingray={Gui={resolution=function()return 1920,1080 end}}
LiveLuaLoader={close_manager=function()closes=closes+1;return true end}
local ctx={log=function(message)error('Unexpected adapter error: '..message)end}
adapter.on_update(ctx,.016);assert(active and menu.visible and not flags.focus and flags.cursor)
local selected,page,row=menu.selected,menu.page,menu.row
focused=false;keys[121]=true;keys[1]=true;adapter.on_update(ctx,.016)
assert(menu.visible and menu.suspended and not active and flags.focus and not flags.cursor,'Blur closed menu or retained capture')
assert(menu.selected==selected and menu.page==page and menu.row==row and closes==1,'Blur changed navigation/loader state')
adapter.on_update(ctx,.016);assert(menu.visible and not active and closes==1)
focused=true;adapter.on_update(ctx,.016);assert(menu.visible and active and closes==2,'Held external hotkey replayed on return')
keys[121]=false;keys[1]=false;adapter.on_update(ctx,.016);keys[121]=true;adapter.on_update(ctx,.016)
assert(not menu.visible and not active and flags.focus and not flags.cursor,'Explicit F10 did not restore game input')
assert(menu.selected==selected and menu.page==page,'Navigation changed during focus round trip')
print('PASS: actual adapter/menu/capture preserves open navigation on blur, releases background capture, reacquires after focus validation, suppresses held external input, and closes/restores explicitly')
