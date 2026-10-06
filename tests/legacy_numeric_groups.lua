local core=assert(loadfile('src/core.lua'))();local bridge=assert(loadfile('src/legacy.lua'))()
local state={mods={[1]={title='Bingus original',order={{id='test.enabled',kind='toggle',label='Enabled',default=false}}}},options={},callbacks={},revision=0}
local value=false;local host={api=1}
function host.register_option()return state end
function host.get()return value end
function host.set(_,v)value=v;return true end
local api=core.new(nil,function()end);local b=bridge.new(api,function()end,core)
b.poll(host);local mods=api.list();assert(#mods==1 and mods[1].name=='Bingus original')
assert(mods[1].handle.set('option_1',true) and value)
assert(b.diagnostic():find('Bingus original',1,true))
state.mods.Other={order={{id='other',kind='toggle',label='Other',default=false}}};state.revision=1
b.poll(host);assert(#api.list()==2)
print('PASS original numeric and compatibility named legacy groups retain names and setters')
