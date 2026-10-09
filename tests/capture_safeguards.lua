local module=dofile('src/capture.lua');local flags={focus=true,cursor=false,clip=false}
local silent=false;local gate=0;local sticky=false
local window={}
for _,pair in ipairs({{'mouse_focus','focus'},{'show_cursor','cursor'},{'clip_cursor','clip'}})do
 local key,name=pair[1],pair[2];window[key]=function()return flags[name]end
 window['set_'..key]=function(v)if not silent then flags[name]=v end end
end
local native={mcm_install=function()return 1 end,mcm_capture=function()gate=1;return 1 end,mcm_captured=function()return gate end,mcm_release=function()if not sticky then gate=0 end end}
local c=module.new(native,window,function()end)
flags.focus=false;local ok,why=c.sync(true,true,1);assert(not ok and gate==0 and why:find('already disabled',1,true))
flags.focus=true;assert(c.sync(true,true,1));silent=true
ok,why=c.release();assert(not ok and c.status().pending_restore and why:find('readback',1,true))
silent=false;assert(c.sync(false,true,1) and flags.focus and not flags.cursor and not flags.clip)
assert(c.sync(true,true,1));sticky=true;ok,why=c.release();assert(not ok and c.status().pending_restore and gate==1)
sticky=false;assert(c.sync(false,true,1) and flags.focus and gate==0)
print('PASS stale baseline refusal, silent setter verification, retained restoration retry and native gate readback')
