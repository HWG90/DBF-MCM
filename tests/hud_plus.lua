-- Original synthetic owner fixtures follow the confirmed public bridge contract.
local Core=dofile('src/core.lua');local HUD=dofile('src/integrations/hud_plus.lua')
local count=0
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));count=count+1;print('PASS '..name)end
local function copy(values)local out={};for key,value in pairs(values)do out[key]=value end;return out end
local function owner()
 local state={live=true,values={['hud.enabled']=true,['hud.opacity']=.8,['hud.style']=0,['hud.layout.x']=.65},calls=0,writes=0}
 local bridge={api=1,name='HD2 HUD+',version='0.2.2',generation={}}
 function bridge.alive()return state.live end
 function bridge.entries()return {
  {id='hud.enabled',kind='toggle',label='Enabled',category='3D HUD',default=true},
  {id='hud.opacity',kind='slider',label='Opacity',category='3D HUD',default=.8,min=.6,max=1,step=.1},
  {id='hud.style',kind='choice',label='Style',category='3D HUD',default=0,choices={'Off','Trajectory','Blast radius'}},
  {id='hud.layout.x',kind='slider',label='Horizontal position',category='Layout',default=.65,min=-5,max=5,step=.01},
 }end
 function bridge.snapshot(token)if token~=bridge.generation or not state.live then return nil,'retired'end;return copy(state.values)end
 function bridge.apply(changes,token)
  if token~=bridge.generation or not state.live then return false,'retired'end
  state.calls=state.calls+1;state.last=copy(changes)
  if state.native_open then return false,'Close or apply the native HUD+ settings before editing MCM'end
  if state.fail_save then return false,'owner save failed'end
  if state.concurrent then for key,value in pairs(state.concurrent)do state.values[key]=value end;state.concurrent=nil end
  for key,value in pairs(changes)do state.values[key]=value end
  if state.clamp then state.values['hud.opacity']=.85 end
  state.writes=state.writes+1
  return true,copy(state.values)
 end
 return bridge,state
end
local function setup()
 local framework_writes=0
 local api=Core.new({load=function()return {}end,save=function()framework_writes=framework_writes+1;return true end})
 local integration=HUD.new(api,function()end);return api,integration,function()return framework_writes end
end
test('late registration owns one provider and converts original zero-based choices',function()
 local api,bridge,no_ini=setup();assert(not bridge.poll())
 local host,state=owner();assert(bridge.poll(host));local mod=api.mods.hud_plus
 assert(#api.list()==1 and mod.name=='HD2 HUD+' and #mod.pages==2 and not mod.pages[1].require_confirmation)
 local key=HUD.control_id('hud.style');assert(mod.handle.get(key)==1)
 assert(mod.handle.edit(key,3));assert(state.values['hud.style']==2 and state.calls==1 and state.writes==1 and no_ini()==0)
 assert(mod.handle.get(key)==3);assert(bridge.poll(host) and #api.list()==1 and state.calls==1)
end)
test('external authoritative values sync without save or redundant callbacks',function()
 local api,integration,no_ini=setup();local host,state=owner();assert(integration.poll(host))
 local revision=api.revision;state.values['hud.opacity']=.9;state.values['hud.style']=1;state.values['hud.layout.x']=.654
 assert(integration.poll(host));local handle=api.mods.hud_plus.handle
 assert(handle.get(HUD.control_id('hud.opacity'))==.9 and handle.get(HUD.control_id('hud.style'))==2)
 assert(handle.get(HUD.control_id('hud.layout.x'))==.654 and api.revision==revision+1)
 assert(state.calls==0 and state.writes==0 and no_ini()==0);assert(integration.poll(host));assert(api.revision==revision+1)
end)
test('full MCM storage snapshots send only edited deltas and merge concurrent owner changes',function()
 local api,integration,no_ini=setup();local host,state=owner();assert(integration.poll(host))
 state.concurrent={['hud.opacity']=.9,['hud.style']=2}
 local handle=api.mods.hud_plus.handle;assert(handle.set(HUD.control_id('hud.enabled'),false))
 assert(state.last['hud.enabled']==false and state.last['hud.opacity']==nil and state.last['hud.style']==nil)
 assert(not state.values['hud.enabled'] and state.values['hud.opacity']==.9 and state.values['hud.style']==2)
 assert(handle.get(HUD.control_id('hud.opacity'))==.9 and handle.get(HUD.control_id('hud.style'))==3)
 assert(state.calls==1 and state.writes==1 and no_ini()==0)
end)
test('owner readback determines the displayed committed value',function()
 local api,integration=setup();local host,state=owner();assert(integration.poll(host));state.clamp=true
 local handle=api.mods.hud_plus.handle;assert(handle.set(HUD.control_id('hud.opacity'),.9))
 assert(state.values['hud.opacity']==.85 and handle.get(HUD.control_id('hud.opacity'))==.85 and state.writes==1)
end)
test('native drafts and failed saves leave cached and owner settings unchanged',function()
 local api,integration,no_ini=setup();local host,state=owner();assert(integration.poll(host));local handle=api.mods.hud_plus.handle
 local key=HUD.control_id('hud.enabled');state.native_open=true
 local ok,err=handle.set(key,false);assert(not ok and err:find('native HUD+',1,true) and handle.get(key) and state.values['hud.enabled'])
 state.native_open=false;state.fail_save=true;ok,err=handle.set(key,false)
 assert(not ok and err=='owner save failed' and handle.get(key) and state.values['hud.enabled'] and state.writes==0 and no_ini()==0)
 state.fail_save=false;assert(handle.set(key,false) and not handle.get(key) and state.writes==1)
end)
test('retired worker tokens reject old handles and a new owner reloads current values',function()
 local api,integration=setup();local old_host,old_state=owner();assert(integration.poll(old_host));local retired=api.mods.hud_plus.handle
 old_state.live=false;assert(not integration.poll(old_host) and not api.mods.hud_plus)
 assert(not pcall(retired.set,HUD.control_id('hud.enabled'),false))
 local fresh,state=owner();state.values['hud.opacity']=.9;assert(integration.poll(fresh))
 assert(api.mods.hud_plus.handle.get(HUD.control_id('hud.opacity'))==.9 and old_state.writes==0 and state.writes==0)
 integration.release();integration.release();assert(not api.mods.hud_plus)
end)
test('unsupported metadata and independently owned registrations remain isolated',function()
 local api,integration=setup();local foreign=api.register({id='hud_plus',name='Independent owner',pages={{id='p',name='P',controls={}}}})
 local host=owner();assert(not integration.poll(host) and api.mods.hud_plus.handle==foreign)
 integration.release();assert(api.mods.hud_plus.handle==foreign);foreign.unregister()
 host.version='different';assert(not integration.poll(host) and not api.mods.hud_plus)
 host=owner();local original=host.entries;host.entries=function()local entries=original();entries[#entries+1]=entries[1];return entries end
 assert(not integration.poll(host) and not api.mods.hud_plus)
end)
test('owner IDs remain stable and distinct without changing native IDs',function()
 assert(HUD.control_id('hud.style')~=HUD.control_id('hud_2estyle'))
 assert(HUD.control_id('hud.style')=='o_hud_2estyle')
 assert(not pcall(HUD.control_id,'../hud.style'));assert(not pcall(HUD.control_id,string.rep('.',40)))
end)
print(string.format('PASS %d HUD+ integration contracts: owner persistence, deltas, enum conversion, readback, drafts and lifecycle',count))
