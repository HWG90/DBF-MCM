local Core=dofile('src/core.lua');local Grouping=dofile('src/grouping.lua');local Menu=dofile('src/menu.lua')
local calls,errors=0,{}
local api=Core.new(nil,function(msg)errors[#errors+1]=msg end,Grouping)
local h=api.register({id='conditional',name='Conditions',pages={{id='main',name='Main',controls={
 {id='random',type='toggle',label='Randomize input delay',default=false},
 {id='delay',type='slider',label='Fixed delay',min=0,max=100,step=1,default=70,
 enabled_if=function(get)calls=calls+1;return not get('random')end},
 {id='mode',type='choice',label='Mode',choices={'Wheel','List'},default=1},
 {id='wheel',type='toggle',label='Wheel only',default=true,disabled_if=function(get)return get('mode')~=1 end},
 {id='extra',type='toggle',label='Visible only in wheel',default=false,visible_if=function(get)return get('mode')==1 end},
}}}})
assert(h.available('delay'));assert(h.edit('delay',42));assert(h.edit('random',true))
assert(not h.available('delay')and h.preview('delay')==70,'disabled draft was retained')
local ok,why=h.edit('delay',50);assert(ok==false and why=='Setting unavailable','disabled write threw or succeeded')
assert(h.discard('main'));assert(h.available('delay')and not h.preview('random'))
assert(h.edit('mode',2));assert(not h.available('wheel')and not h.available('extra'))
local menu=Menu.new(api);menu.visible=true;local labels={}
for _,c in ipairs(menu.compose(1920,1080))do if c.type=='text'then labels[c.text]=true end end
assert(not labels['Visible only in wheel'],'hidden control was rendered')
assert(h.confirm('main'));assert(h.get('mode')==2 and not h.available('wheel'))
assert(h.edit('mode',1));assert(h.available('wheel'));assert(h.discard('main'));assert(not h.available('wheel'))
local before=calls;for _=1,10000 do api.list()end;assert(calls==before,'idle catalogue reevaluates predicates')
assert(h.set_condition('wheel',{enabled_if=function()error('provider failed')end}));assert(not h.available('wheel'))
local logs=#errors;h.refresh_conditions();assert(#errors==logs,'condition error logged every refresh')
assert(h.set_condition('wheel',{enabled_if=function()return true end}));assert(h.available('wheel'))
assert(h.set_condition('wheel',{enabled_if=function()return 'yes'end}));assert(not h.available('wheel'))
assert(h.set_condition('wheel',{}));assert(h.available('wheel'))
-- A cached composite must invalidate as soon as the imported owner changes.
local child=api.register({id='child',name='Child',parent_name='Conditions',pages={{id='child',name='Child',controls={{id='flag',type='toggle',label='Child flag',default=true}}}}})
local first=api.list()[1];assert(first.controls.delay and not first.controls.delay.disabled)
assert(h.edit('random',true));local second=api.list()[1];assert(second.controls.delay.disabled,'mounted cache retained enabled copy')
assert(first.handle.edit('delay',2)==false,'stale grouped hit bypassed canonical availability')
-- Legacy native-ID predicates must see unconfirmed drafts and invalidate outer cache.
local Compat=dofile('src/compat.lua');local Legacy=dofile('src/legacy.lua');local host=Compat.new(nil)
assert(host.register_option('test.mode',{mod='Legacy conditions',type='toggle',label='Mode',default=false}))
assert(host.register_option('test.amount',{mod='Legacy conditions',type='slider',label='Amount',min=0,max=10,step=1,default=5,enabled_if=function(get)return not get('test.mode')end}))
local other=Core.new(nil,nil,Grouping);Legacy.new(other,function()end,Core).poll(host)
local legacy=other.list()[1];local toggle,slider=legacy.pages[1].controls[1],legacy.pages[1].controls[2]
local rev=other.revision;assert(legacy.handle.edit(toggle.id,true));assert(slider.disabled and other.revision>rev)
assert(legacy.handle.edit(slider.id,3)==false);assert(legacy.handle.discard('settings'));assert(not slider.disabled)
-- A pre-existing slider drag is cancelled when its dependency flips.
local control=api.mods.conditional.controls.delay;h.discard('main');menu=Menu.new(api);menu.visible=true;menu.compose(1920,1080)
local target
for _,c in ipairs(menu.compose(1920,1080))do if c.ui_role=='slider_track'then target=c;break end end
assert(target);menu.tick({down=function(k)return k==1 end,mouse=function()return target.x+target.w/2,target.y end})
assert(h.edit('random',true));assert(pcall(menu.tick,{down=function()return false end,mouse=function()return target.x,target.y end}))
assert(h.get('delay')==70,'stale drag wrote disabled slider')
print('PASS conditional drafts, confirm/discard, mounted invalidation, legacy native IDs, errors, hidden controls, idle cache and stale drag')

