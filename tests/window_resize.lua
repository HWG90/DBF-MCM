local core=assert(loadfile('src/core.lua'))();local ui=assert(loadfile('src/menu.lua'))()
local api=core.new();local controls={{id='enabled',type='toggle',label='Enabled',default=true}}
for i=1,40 do controls[#controls+1]={id='v'..i,type='slider',label='Value '..i,min=0,max=100,step=1,default=10}end
local viewport
api.register({id='demo',name='Demo',pages={{id='general',name='General',require_confirmation=false,render_preview=function(v)viewport=v;return {}end,controls=controls}}})
local m=ui.new(api);m.visible=true
local down=false;local x,y=0,0
local input={down=function(k)return k==1 and down end,mouse=function()return x,y end}
local function compose()return m.compose(1920,1080)end
local function press(px,py)x,y=px,py;down=true;m.tick(input)end
local function move(px,py)x,y=px,py;m.tick(input)end
local function release()down=false;m.tick(input);compose()end
compose();local b=m.window_bounds;assert(b.w==1500 and b.h==820 and viewport)
-- Northeast corner grows both axes and stays inside the screen.
press(b.x+b.w-2,b.y+b.h-2);move(4000,4000);release();b=m.window_bounds
assert(b.x+b.w<=1920 and b.y+b.h<=1080)
-- Southwest keeps the opposite corner anchored and clamps minimum dimensions.
press(b.x+2,b.y+2);move(4000,4000);release();b=m.window_bounds
assert(m.window_width==1100 and m.window_height==600)
assert(m.settings_visible==6 and m.tree_visible==10)
-- Title drag clamps position without changing dimensions.
press(b.x+100,b.y+b.h-30);move(-4000,-4000);release();b=m.window_bounds
assert(b.x==0 and b.y==0 and b.w==1100 and b.h==600)
-- Toggle hit box follows resized content; same authoritative handle is edited.
local commands=compose();local on
for _,c in ipairs(commands)do if c.type=='text' and c.text=='ON'then on=c end end
assert(on,'ON not rendered');press(on.x,on.y);release();assert(api.get('demo','enabled')==false,'toggle hit missed')
-- Wheel limits use the current visible row budget.
m.wheel(-120,800,350);assert(m.scroll>0);compose()
-- Compact preview is a popout, not an overlapping inline panel.
local button
for _,c in ipairs(compose())do if c.type=='text' and c.text=='OPEN HUD PREVIEW'then button=c end end
assert(button);press(button.x,button.y);release();assert(m.preview_window and viewport.w>0 and viewport.h>0)
-- Every edge changes only its own axis, keeping its opposite edge anchored.
for _,edge in ipairs({'w','e','s','n'})do
 m.preview_window=nil;m.window_width=1500;m.window_height=820;m.window_x=210;m.window_y=130;compose();local before=m.window_bounds
 local px=edge=='w' and before.x+2 or edge=='e' and before.x+before.w-2 or before.x+before.w/2
 local py=edge=='s' and before.y+2 or edge=='n' and before.y+before.h-2 or before.y+before.h/2
 press(px,py);move(px+(edge=='w' and 50 or edge=='e' and -50 or 0),py+(edge=='s' and 40 or edge=='n' and -40 or 0));release()
 local after=m.window_bounds
 if edge=='w' or edge=='e'then assert(after.h==before.h and after.w<before.w)else assert(after.w==before.w and after.h<before.h)end
end
-- Close cancels resize and produces no drawing; recovery clears drag too.
m.key(121);assert(#compose()==0);m.recover();assert(not m.visible)
-- Changing monitor resolution clamps the saved geometry to current bounds.
m.visible=true;m.compose(800,600);b=m.window_bounds
assert(b.x>=0 and b.y>=0 and b.x+b.w<=800 and b.y+b.h<=600)
print('PASS corner resizing, screen/minimum bounds, title drag, resized value hits, scroll budget, compact preview, close and resolution change')
