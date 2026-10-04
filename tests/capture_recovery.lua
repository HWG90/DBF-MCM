local M=assert(loadfile('src/capture.lua'))()
local flags={focus=true,cursor=false,clip=true};local refuse=false;local captured=false;local logs={}
local window={mouse_focus=function()return flags.focus end,show_cursor=function()return flags.cursor end,clip_cursor=function()return flags.clip end,set_mouse_focus=function(v)if refuse then return false end;flags.focus=v end,set_show_cursor=function(v)flags.cursor=v end,set_clip_cursor=function(v)flags.clip=v end}
local native={mcm_install=function()return 1 end,mcm_capture=function()captured=true;return 1 end,mcm_captured=function()return captured and 1 or 0 end,mcm_release=function()captured=false end}
local c=M.new(native,window,function(s)logs[#logs+1]=s end)
assert(c.sync(true,true,1) and c.status().owner=='mcm' and not flags.focus)
refuse=true;local ok,why=c.release();assert(not ok and why:match('set_mouse_focus') and not captured and c.status().pending_restore)
assert(not c.sync(true,true,1) and not captured)
assert(not c.shutdown() and c.status().pending_restore)
refuse=false;assert(c.sync(false,true,1) and flags.focus and not flags.cursor and flags.clip and not c.status().owner)
assert(c.sync(true,true,1));assert(c.sync(false,false,1) and flags.focus and not captured)
local token=assert(c.acquire('camera'));assert(not c.release() and c.owns(token));assert(c.release(token))
print('PASS menu restoration refusal retains snapshot, retries without reacquisition, restores focus-loss state, and preserves foreign leases')
