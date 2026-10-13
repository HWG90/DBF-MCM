local Core=dofile('src/core.lua');local Menu=dofile('src/menu.lua')
local api=Core.new();local commits=0
local handle=api.register({id='blur',name='Blur fixture',on_change=function()commits=commits+1 end,pages={
 {id='main',name='Main',require_confirmation=false,controls={
  {id='focus',type='slider',label='Focus',default=5,min=.1,max=200,step=.01,fine_step=.001,commit_on_blur=true},
  {id='other',type='slider',label='Other',default=20,min=0,max=100,step=1,commit_on_blur=true},
  {id='legacy',type='slider',label='Legacy',default=3,min=0,max=10,step=1}}},
 {id='second',name='Second',require_confirmation=false,controls={}}}})
local mod=api.mods.blur;local menu=Menu.new(api);menu.visible=true;menu.focus='settings'
local keys={};local px,py=1,1
local input={down=function(k)return keys[k]or false end,mouse=function()return px,py end}
local function edit(id,text)menu.text_edit={mod=mod,control=mod.controls[id],text=text,replace=false}end
local function click(x,y)px,py=x,y;keys[1]=true;menu.tick(input);keys[1]=false;menu.tick(input)end
menu.compose(1920,1080);edit('focus','1.405');local before=commits;click(1,1)
assert(math.abs(handle.get('focus')-1.405)<1e-9 and not menu.text_edit and commits==before+1,'Opt-in pointer blur must commit once at fine precision')
menu.tick(input);assert(commits==before+1)
edit('focus','2');menu.key(27);assert(math.abs(handle.get('focus')-1.405)<1e-9 and not menu.text_edit,'Escape must cancel')
for _,value in ipairs({'.','-','999','1..2'})do
 edit('focus',value);before=commits;click(1,1)
 assert(menu.text_edit and commits==before and math.abs(handle.get('focus')-1.405)<1e-9,'Invalid/out-of-range blur must retain the safe draft')
 menu.key(27)
end
edit('legacy','7');click(1,1);assert(handle.get('legacy')==3 and not menu.text_edit,'Default slider blur policy must remain unchanged')
menu.page=1;local commands=menu.compose(1920,1080);local other
for _,c in ipairs(commands)do if c.full_text=='20'and c.text_bounds then other=c.text_bounds end end
assert(other,'Expected numeric hit target');edit('focus','3');click(other.x+other.w/2,other.y+other.h/2)
assert(handle.get('focus')==3 and handle.get('other')==20 and menu.text_edit and menu.text_edit.control==mod.controls.other,'Cross-field click must update only the owned edit')
menu.key(27);edit('focus','4');menu.key(34)
assert(handle.get('focus')==4 and menu.page==2 and not menu.text_edit,'Page navigation must blur-commit')
menu.page=1;menu.row=1;menu.key(39,false,true);assert(math.abs(handle.get('focus')-4.001)<1e-9,'Shift arrow must use fine_step')
menu.key(39,false,false);assert(math.abs(handle.get('focus')-4.011)<1e-9,'Regular arrow must preserve step')
edit('focus','6');mod.controls.focus.disabled=true;before=commits;click(1,1)
assert(commits==before and math.abs(handle.get('focus')-4.011)<1e-9 and not menu.text_edit,'Disabled controls cannot commit')
mod.controls.focus.disabled=false;edit('focus','7');menu.visible=false;menu.compose(1920,1080)
assert(handle.get('focus')==7 and not menu.text_edit,'Normal close must commit a valid opted-in numeric value')
menu.visible=true;edit('focus','8');handle.unregister();before=commits;click(1,1)
assert(commits==before and not menu.text_edit,'Removed owner cannot commit a foreign/stale field')
local pending=api.register({id='pending_blur',name='Pending blur',pages={{id='p',name='Page',controls={
 {id='value',type='slider',label='Value',default=1,min=0,max=10,step=.01,fine_step=.001,commit_on_blur=true}}}}})
local owner=api.mods.pending_blur;menu.compose(1920,1080)
menu.text_edit={mod=owner,control=owner.controls.value,text='2.345',replace=false};click(1,1)
assert(pending.get('value')==1 and math.abs(pending.preview('value')-2.345)<1e-9,'Blur must preserve author-requested page confirmation')
assert(not pcall(function()api.register({id='bad',name='Bad',pages={{id='p',name='Page',controls={{id='v',type='slider',label='V',default=0,min=0,max=1,step=.1,fine_step=.2}}}}})end),'Invalid fine_step must fail registration')
print('PASS MCM opt-in numeric blur, Escape, safe invalid draft, defaults, field ownership, page/close, fine step and lost owner')
