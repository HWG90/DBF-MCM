local Capture=dofile('src/capture.lua')
local flags={focus=false,cursor=true,clip=false};local captured=0;local acquisitions=0;local closed=0
local native={mcm_install=function()return 1 end,mcm_capture=function()captured=1;acquisitions=acquisitions+1;return 1 end,mcm_captured=function()return captured end,mcm_release=function()captured=0 end}
local window={};for _,field in ipairs({{'mouse_focus','focus'},{'show_cursor','cursor'},{'clip_cursor','clip'}})do local getter,key=field[1],field[2];window[getter]=function()return flags[key]end;window['set_'..getter]=function(value)flags[key]=value end end
local capture=Capture.new(native,window,function()end)
assert(not capture.sync(true,true,1));assert(acquisitions==0 and flags.focus==false and flags.cursor)
local state={open=true,current_owned=true}
local parent={restoration_snapshot={focus=false,cursor=true,clip=false},gameplay_snapshot={focus=true,cursor=false,clip=true},validate=function()return state.open and state.current_owned end,status=function()return state end,on_close=function()closed=closed+1;state.current_owned=false;return true end}
assert(capture.sync(true,true,1,parent));assert(captured==1 and flags.focus==false and flags.cursor and flags.clip)
assert(capture.release());assert(captured==0 and not flags.focus and flags.cursor and not flags.clip and closed==1)
state={open=true,current_owned=true};assert(capture.sync(true,true,1,parent));state={covered=true}
assert(not capture.sync(true,true,1,parent));assert(captured==0 and capture.status().pending_restore)
state={open=true,current_owned=true};assert(capture.release());assert(not capture.status().pending_restore)
state={open=true,current_owned=true};assert(capture.sync(true,true,1,parent));state={closed=true}
assert(not capture.sync(true,true,1,parent));assert(flags.focus and not flags.cursor and flags.clip and not capture.status().pending_restore)
flags.focus=false;flags.cursor=true;flags.clip=false;state={open=true,current_owned=true};parent.restoration_snapshot.clip=true
assert(not capture.sync(true,true,1,parent));assert(acquisitions==3 and flags.clip==false,'mismatched native snapshot acquired input')
print('PASS native parent requires verified ownership and matching flags, restores parent/game, retains covered restoration and releases native gate')
