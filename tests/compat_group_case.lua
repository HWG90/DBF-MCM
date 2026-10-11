local compat=dofile('src/compat.lua')
local a={id='native_stratagem_radial.enabled',kind='toggle',label='Enable Mod',default=true}
local b={id='native_stratagem_radial.hide_sos',kind='toggle',label='Blacklist SOS',default=false}
local callback=function()end
local state={mods={["Diver's Best Friend"]={order={a}},["DIVER'S BEST FRIEND"]={order={b,a}}},
options={[a.id]=a,[b.id]=b},values={[a.id]=false,[b.id]=true},callbacks={[a.id]={callback}},revision=4}
local api=compat.new(nil,state)
local count=0;for _ in pairs(state.mods)do count=count+1 end
assert(count==1 and #state.mods["DIVER'S BEST FRIEND"].order==2)
assert(api.get(a.id)==false and api.get(b.id)==true and state.callbacks[a.id][1]==callback)
assert(state.options[a.id]==a and state.options[b.id]==b and state.revision==5)
assert(api.register_option('native_stratagem_radial.extra',{mod="Diver's Best Friend",label='Extra',type='toggle',default=false}))
assert(#state.mods["DIVER'S BEST FRIEND"].order==3)
local revision=state.revision;compat.new(nil,state);assert(state.revision==revision,'normalization is idempotent')
-- Blacklist mounting sees exactly one parent, preserving a separate page.
local grouping=dofile('src/grouping.lua')
local core=dofile('src/core.lua').new(nil,function()end)
local legacy=dofile('src/legacy.lua').new(core,function()end,dofile('src/core.lua'))
legacy.poll(api)
core.register({id='dbf_ass_blacklist',name='Blacklist',parent_name="Diver's Best Friend",pages={{id='blacklist',name='Blacklist',controls={}}}})
local list={};for _,mod in pairs(core.mods)do list[#list+1]=mod end
local grouped=grouping.list(list)
assert(#grouped==1 and #grouped[1].pages==2,'one DBF parent with Settings and Blacklist')
print('Case-normalized legacy groups: values, callbacks, deduplication, new registrations and Blacklist mounting passed')
