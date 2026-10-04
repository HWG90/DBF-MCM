local root=assert(os.getenv('DBF_LLL_ROOT'),'Set DBF_LLL_ROOT to the matching LLL source checkout')
_G.LLL_UI_CORE={new=function()return {}end};_G.stingray=nil
local loader={};local ui=assert(loadfile(root..'/src/ui.lua'))()(loader,{}, {bind=function()end},function()end)
local menu={visible=false}
local function set(fn,wanted,value)
 for i=1,64 do local n=debug.getupvalue(fn,i);if not n then break end;if n==wanted then debug.setupvalue(fn,i,value);return end end
 error('Missing upvalue '..wanted)
end
set(ui.open,'menu',menu)
_G.DBFMCM={close=function()return false,'restore pending'end}
local ok,why=ui.open();assert(ok==false and why=='restore pending' and not menu.visible)
_G.DBFMCM.close=function()return true end
assert(ui.open() and menu.visible)
local release_calls=0
set(ui.close,'capture',{release=function()release_calls=release_calls+1;return false,'pending'end,status=function()return {pending_restore=true}end})
assert(loader.close_manager()==false and not menu.visible and release_calls==1)
assert(loader.input_status().pending_restore)
print('PASS actual LLL UI refuses failed MCM handoff and propagates close restoration failure')
