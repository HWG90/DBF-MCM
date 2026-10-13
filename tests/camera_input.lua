local factory=dofile('src/camera_input.lua')
local mode,focused,allowed=0,true,true
local solo=true
local down={};local owned;local restoration=true
local native={mcm_release=function()mode=0 end,mcm_captured=function()return mode end,
    mcm_photo_capture=function()if not solo then return 0 end;mode=3;return 1 end,
    mcm_photo_pause_allowed=function()return solo and 1 or 0 end,mcm_install=function()return 1 end,mcm_capture=function(v)mode=v;return 1 end}
local capture={acquire=function()if owned then return nil,'busy' end;owned={};return owned end,
    owns=function(t)return t==owned end,release=function(t)assert(t==owned);if not restoration then return false,'restore failed' end;owned=nil;return true end}
local input={photo_check=function()end,poll=function()end,focused=function()return focused end,window=function()return {} end,
    down=function(k)return down[k] or false end,wheel=function()return 120 end}
local camera=factory.new(native,capture,input,function()return allowed end)
down[87]=true;down[16]=true;assert(camera.acquire());assert(owned and mode==3)
down[87]=true;down[16]=true;local s=camera.sample();assert(s.forward and s.up and s.wheel==120)
allowed=false;assert(not camera.sample());assert(mode==0 and not owned)
allowed=true;down={};assert(camera.acquire());focused=false;assert(not camera.sample());assert(not owned)
focused=true;assert(camera.acquire());restoration=false
assert(camera.release()==false);assert(owned and mode==0)
restoration=true;assert(camera.release());assert(not owned)
down[73]=true;assert(camera.acquire({forward=73}));down[73]=true;assert(camera.sample({forward=73}).forward);assert(camera.release());
input.lock_aim=function()error('focus unavailable')end;down={};assert(not camera.acquire());assert(mode==0 and not owned);input.lock_aim=nil
mode=1;assert(not camera.acquire());assert(mode==1);mode=0
solo=false;assert(camera.acquire());assert(camera.sample());assert(not camera.pause_allowed());assert(camera.release())
solo=true;assert(camera.pause_allowed());input.photo_check=nil;assert(not camera.pause_allowed())
print('Camera input: held keyboard activation, multiplayer freecam, pause gate and restoration passed')

input.photo_check=function()end;input.menu_cursor=function(menu)return true end;input.mouse=function()return 125,250 end
assert(camera.acquire());assert(camera.set_focus(true));assert(mode==1)
local pointer=camera.menu_sample();assert(pointer.x==125 and pointer.y==250)
assert(camera.set_focus(false));assert(mode==3 and camera.sample());assert(camera.release())
print('Photo input focus: menu/camera capture modes, pointer sampling and restoration passed')

local seconds=12
input.now=function()return seconds end
local timed=factory.new(native,capture,input,function()return allowed end)
assert(timed.now()==12 and mode==0,'Photo effects must be able to read time without a camera input lease')
assert(timed.acquire());assert(timed.set_focus(true));seconds=12.08
assert(timed.now()==12.08 and timed.menu_sample().dt>0,'Menu focus must retain the real-time effect clock')
assert(timed.release());seconds=13;assert(timed.now()==13)
print('Photo effect clock: lease-free monotonic timer, menu focus and release passed')
