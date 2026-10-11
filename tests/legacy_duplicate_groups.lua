local core=dofile('src/core.lua')
local grouping=dofile('src/grouping.lua')
local state={mods={},options={},callbacks={},revision=1};local values={enabled=true,hide_sos=false,late=false}
local a={id='enabled',kind='toggle',label='Enable Mod',default=true}
local b={id='hide_sos',kind='toggle',label='Blacklist SOS',default=false}
state.mods[1]={title="Diver's Best Friend",order={a}}
state.mods[2]={title="DIVER'S BEST FRIEND",order={b,a}}
state.options.enabled=a;state.options.hide_sos=b
local calls=0;state.callbacks.enabled={function()calls=calls+1 end}
local host={api=1} -- Real Bingus host: no compatibility replacement involved.
function host.register_option(id,spec)state.options[id]=spec end
function host.get(id)return values[id]end
function host.set(id,value)values[id]=value;return true end
local api=core.new(nil,function()end)
local bridge=dofile('src/legacy.lua').new(api,function()end,core)
api.register({id='dbf_ass_blacklist',name='Blacklist',parent_name="Diver's Best Friend",pages={{id='blacklist',name='Blacklist',controls={}}}})
bridge.poll(host)
local function listed()local list={};for _,m in pairs(api.mods)do list[#list+1]=m end;return grouping.list(list)end
local list=listed();assert(#list==1 and #list[1].pages==2)
local mod=api.mods.bingus_1;local count=0;for _ in pairs(mod.controls)do count=count+1 end;assert(count==2)
for key,c in pairs(mod.controls)do if c.label=='Enable Mod'then assert(mod.handle.set(key,false))end end
assert(values.enabled==false and calls==1)
assert(#state.mods[1].order==1 and #state.mods[2].order==2,'native registry remains untouched')
state.mods[3]={title="Diver's Best Friend",order={{id='late',kind='toggle',label='Late',default=false}}};state.revision=2
bridge.poll(host);list=listed();assert(#list==1 and #list[1].pages==2)
count=0;for _ in pairs(api.mods.bingus_1.controls)do count=count+1 end;assert(count==3)
bridge.poll(host);assert(#listed()==1)
print('Original-host duplicate groups: one Settings/Blacklist parent, callbacks, values and late registrations passed')
