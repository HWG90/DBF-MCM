local M=assert(loadfile('src/capture.lua'))()
local flags={focus=true,cursor=false,clip=true};local fail=false
local w={mouse_focus=function()return flags.focus end,show_cursor=function()return flags.cursor end,clip_cursor=function()return flags.clip end,set_mouse_focus=function(v)if fail then return false end;flags.focus=v end,set_show_cursor=function(v)flags.cursor=v end,set_clip_cursor=function(v)flags.clip=v end}
local function native()local active=0;return {mcm_install=function()return 1 end,mcm_capture=function()active=1;return 1 end,mcm_captured=function()return active end,mcm_release=function()active=0 end}end
local root=assert(os.getenv('DBF_LLL_ROOT'),'Set DBF_LLL_ROOT to the matching LLL source checkout')
local loader=assert(loadfile(root..'/src/ui/capture.lua'))().new(native(),w,function()end)
local mcm=M.new(native(),w,function()end)
assert(loader.sync(true,true,1));assert(not flags.focus)
fail=true;assert(loader.release()==false);assert(loader.status().pending_restore)
fail=false;assert(loader.release());assert(flags.focus)
assert(mcm.sync(true,true,1));assert(mcm.release());assert(flags.focus and not flags.cursor and flags.clip)
for _,path in ipairs({'src/adapter.lua',root..'/src/ui.lua'})do assert(loadfile(path))end
print('PASS loader restoration retry, ordered handoff baseline, and source compilation')

for _,field in ipairs({'set_mouse_focus','set_show_cursor','set_clip_cursor'})do
 local original=w[field];assert(mcm.sync(true,true,1));w[field]=function()error('refused '..field)end
 assert(mcm.release()==false and mcm.status().pending_restore);w[field]=original;assert(mcm.release())
 assert(flags.focus and not flags.cursor and flags.clip)
end
print('PASS restoration exceptions retain every cursor field for retry')
