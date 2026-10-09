-- Optional owner API supplied by the separately prepared local HUD+ bridge patch.
-- The HUD+ owner keeps its configuration file, validation and native apply path.
local H={}
function H.control_id(id)
 assert(type(id)=='string' and id:match('^[%w_.-]+$'),'Invalid HUD+ option ID')
 local result='o_'..id:gsub('[^%w]',function(char)return string.format('_%02x',char:byte())end)
 assert(#result<=80,'HUD+ option ID exceeds MCM limits');return result
end
local function plain(value,fallback)
 return type(value)=='string' and value:gsub('[%c]',' '):sub(1,512) or fallback
end
local function converted(route,value,to_owner)
 if route.kind=='choice'then
  assert(type(value)=='number' and value==value and value%1==0,'Invalid HUD+ choice')
  local index=value+(to_owner and 0 or 1)
  assert(index>=1 and index<=#route.choices,'HUD+ choice outside range')
  return value+(to_owner and -1 or 1)
 elseif route.kind=='toggle'then assert(type(value)=='boolean','Invalid HUD+ toggle')
 else assert(type(value)=='number' and value==value and value>=route.min and value<=route.max,'Invalid HUD+ slider')end
 return value
end
local function alive(binding)
 return binding.bridge.generation==binding.generation and binding.bridge.alive()==true
end
local function snapshot(binding)
 assert(alive(binding),'HUD+ bridge was retired')
 local values,err=binding.bridge.snapshot(binding.generation)
 assert(type(values)=='table',err or 'HUD+ owner snapshot unavailable')
 local result={};for id,route in pairs(binding.routes)do result[id]=converted(route,values[route.owner_id],false)end
 return result,values
end
function H.new(api,log)
 log=log or function()end
 local self={};local seen,binding,handle,mod,last_error
 local function clear()
  if handle then handle.unregister()end
  binding,handle,mod=nil,nil,nil
 end
 local function install(bridge)
  assert(type(bridge)=='table' and bridge.api==1 and bridge.version=='0.2.2','Unsupported HUD+ bridge')
  assert(type(bridge.alive)=='function' and type(bridge.snapshot)=='function' and type(bridge.apply)=='function' and type(bridge.entries)=='function','Incomplete HUD+ bridge')
  assert(bridge.generation~=nil and bridge.alive()==true,'HUD+ bridge is not ready')
  assert(not api.mods.hud_plus,'HUD+ already has an independently owned MCM registration')
  local next_binding={bridge=bridge,generation=bridge.generation,routes={}}
  local entries=bridge.entries();assert(type(entries)=='table' and #entries>0,'HUD+ has no settings')
  local pages,groups={},{}
  for _,entry in ipairs(entries)do
   local id=H.control_id(entry.id);assert(not next_binding.routes[id],'Duplicate HUD+ option ID')
   local category=plain(entry.category,'Settings');local page=groups[category]
   if not page then page={id='group_'..(#pages+1),name=category,require_confirmation=false,controls={}};groups[category]=page;pages[#pages+1]=page end
   local route={owner_id=entry.id,kind=entry.kind,choices=entry.choices,min=entry.min,max=entry.max}
   assert(route.kind=='toggle' or route.kind=='slider' or route.kind=='choice','Unsupported HUD+ control')
   if route.kind=='choice'then assert(type(route.choices)=='table' and #route.choices>0,'HUD+ choices required')end
   next_binding.routes[id]=route
   page.controls[#page.controls+1]={id=id,type=entry.kind,label=plain(entry.label,entry.id),description=plain(entry.description,''),
    default=converted(route,entry.default,false),min=entry.min,max=entry.max,step=entry.step,choices=entry.choices,presentation=entry.kind=='choice' and 'dropdown' or nil}
  end
  local storage={}
  function storage.load()local values,raw=snapshot(next_binding);next_binding.base=raw;return values end
  function storage.save(_,values)
   if binding~=next_binding or not alive(next_binding)then return false,'HUD+ bridge was retired'end
   local changes={}
   for id,route in pairs(next_binding.routes)do
    local value=converted(route,values[id],true)
    if value~=next_binding.base[route.owner_id]then changes[route.owner_id]=value end
   end
   if next(changes)then
    local ok,err=next_binding.bridge.apply(changes,next_binding.generation)
    if not ok then return false,err end
   end
   -- Refresh all committed values so concurrent native edits are not overwritten.
   local committed,raw=snapshot(next_binding)
   for id,value in pairs(committed)do values[id]=value end
   next_binding.base=raw;return true
  end
  binding=next_binding
  handle=api.register({id='hud_plus',name='HD2 HUD+',description='HUD+ settings use its existing configuration and native apply methods. Close the native HUD+ settings before editing here.',storage=storage,pages=pages})
  mod=api.mods.hud_plus
  -- Preserve authoritative values that are between the menu slider's display steps.
  local values,raw=snapshot(binding);mod.values=values;binding.base=raw
  log('HUD+ owner bridge registered ('..#entries..' settings)')
 end
 function self.poll(bridge)
  if bridge==nil then bridge=rawget(_G,'HD2HUDPlusMCMBridge')end
  if bridge~=seen then clear();seen=bridge;last_error=nil end
  if bridge==nil then return false,'HUD+ owner bridge is not loaded'end
  if not handle then
   if last_error then return false,last_error end
   local ok,err=pcall(install,bridge)
   if not ok then clear();last_error=tostring(err);log('HUD+ integration unavailable: '..last_error);return false,last_error end
  end
  if api.mods.hud_plus~=mod then clear();last_error='HUD+ registration ownership changed';return false,last_error end
  local ok,values,raw=pcall(snapshot,binding)
  if not ok then clear();last_error=tostring(values);log('HUD+ owner bridge retired');return false,last_error end
  local changed=false
  for id,value in pairs(values)do if mod.values[id]~=value then changed=true;mod.values[id]=value end end
  binding.base=raw;if changed then api.revision=api.revision+1 end
  return true
 end
 function self.release()clear();seen=nil;last_error=nil end
 function self.diagnostic()return handle and 'HUD+ owner bridge active' or (last_error or 'HUD+ owner bridge not loaded')end
 return self
end
return H
