-- Read the installed Lua registry; never replace the legacy registration API.
local M={}
local function state_of(host)
 if not host or host.api~=1 or type(host.register_option)~='function' or not debug or not debug.getupvalue then return end
 for i=1,40 do local name,value=debug.getupvalue(host.register_option,i);if not name then break end
  if name=='state' and type(value)=='table' and type(value.mods)=='table' and type(value.options)=='table' and type(value.callbacks)=='table' then return value end
 end
end
function M.new(api,log,core)
 local self={};local owner,registry;local imported={};local revision=-1;local appearance_seen
 local function clear()if appearance_seen then appearance_seen.hidden=nil end;for _,id in ipairs(imported)do api.mods[id]=nil end;imported={};api.revision=api.revision+1 end
 function self.diagnostic()
  local names={};for name in pairs(registry and registry.mods or {})do names[#names+1]=name end;table.sort(names)
  local registered=0;for _ in pairs(registry and registry.options or {})do registered=registered+1 end
  local visible=0;for _,mod in pairs(api.mods)do if not mod.hidden then visible=visible+1 end end
  return 'host='..tostring(owner~=nil)..' compat='..tostring(owner and owner.mcm_compat==true)..' registry='..tostring(registry~=nil)..' options='..registered..' visible='..visible..' groups='..table.concat(names,', ')
 end
 function self.release()clear();owner=nil;registry=nil end
 function self.poll(host)
  if host~=owner then
   clear();owner=host;registry=state_of(host);revision=-1
   -- Preserve registrations from either provider, including the original API.
   -- Native mods may register before MCM supplies its compatibility API.
   if registry then package.loaded['dbf_mcm.compat_registry']=registry end
  end
  if not registry then return end
  local appearance=api.mods.dbf_hud_fonts
  if revision==registry.revision and appearance==appearance_seen then return end
  appearance_seen=appearance
  clear();revision=registry.revision
  local names={};for name in pairs(registry.mods)do names[#names+1]=name end;table.sort(names)
  for index,name in ipairs(names)do
   local direct_hud=appearance and appearance.name=='DBF-HUD'
   if not (direct_hud and (name=='DBF-HUD' or name=='DBF-HUD PLACEMENT' or name=='DBF-HUD LAYOUT EDITOR')) then
   local source=registry.mods[name];local controls={};local links={};local pending={}
   for n,o in ipairs(source.order or {})do
    if (o.kind=='toggle' or o.kind=='slider' or o.kind=='choice') and not (name=='DBF-HUD' and appearance) then
     local key='option_'..n;local c={id=key,type=o.kind,label=o.label or o.id,description=o.description or '',default=o.default,min=o.min,max=o.max,step=o.step,choices=o.choices}
     controls[#controls+1]=c;links[key]=o
    end
   end
   if #controls>0 or (name=='DBF-HUD' and appearance) then
    local id='bingus_'..index;local temp=core.new(nil,log)
    local handle=temp.register({id=id,name=name,description='Bingus Mod Options Menu compatibility. Settings apply immediately.',pages={{id='settings',name='Settings',controls=controls}}})
    local mod=temp.mods[id];mod.legacy=true;local validate_set=handle.set;local validated_get=handle.get
    function handle.get(key)local o=links[key];if not o then return end;if pending[key]~=nil then return pending[key]end;return host.get(o.id)end
    function handle.set(key,value)
     local o=assert(links[key],'Unknown legacy option')
     local ok,err=validate_set(key,value);if not ok then return false,err end
     value=validated_get(key);local old=host.get(o.id)
     if old==value then return true end
     ok,err=host.set(o.id,value);if not ok then return false,err end
     for _,callback in ipairs(registry.callbacks[o.id] or {})do
      local called,why=pcall(callback,value,o.id);if not called then log('Legacy callback failed: '..tostring(why))end
     end
     return true
    end
    function handle.reset(key)return handle.set(key,links[key].default)end
    api.mods[id]=mod;imported[#imported+1]=id
   end
  end
   end
  -- Explicit compatibility grouping; original Bingus registration IDs remain intact.
  local root,children
  children={}
  for _,id in ipairs(imported)do local mod=api.mods[id]
   if mod.name=='DBF-HUD' then root=mod
   elseif mod.name=='DBF-HUD LAYOUT EDITOR' then children.layout_editor=mod
   elseif mod.name=='DBF-HUD PLACEMENT' then children.placement=mod end
  end
  if root and appearance then children.appearance=appearance end
  if root then
   local routes={};local page_routes={};local base=root.handle
   for key in pairs(root.controls)do routes[key]={handle=base,key=key}end
   root.categories={{id='hud',name='HUD'}};root.pages[1].name='General';root.pages[1].category='hud'
   for _,entry in ipairs({{id='layout_editor',name='Layout Editor'},{id='placement',name='Placement'},{id='appearance',name='Appearance'}})do
    local child=children[entry.id]
    if child then
     for _,oldpage in ipairs(child.pages)do
      local page={id=entry.id..'_'..oldpage.id,name=entry.id=='layout_editor' and 'Layout' or (entry.id=='appearance' and oldpage.name or entry.name),category='hud',render_preview=oldpage.render_preview,controls={},pending={},actions={},require_confirmation=oldpage.require_confirmation==true}
      for _,old in ipairs(oldpage.controls)do
       local c={};for k,v in pairs(old)do c[k]=v end;c.page=page
       if old.id then c.id=entry.id..'_'..old.id;routes[c.id]={handle=child.handle,key=old.id};root.controls[c.id]=c end
       page.controls[#page.controls+1]=c
      end
      page_routes[page.id]={handle=child.handle,id=oldpage.id}
      root.pages[#root.pages+1]=page
     end
     if entry.id=='appearance' then child.hidden=true else api.mods[child.id]=nil end
    end
   end
   local grouped={id=root.id}
   for _,method in ipairs({'get','preview','set','edit','reset','activate','queue'})do
    local name=method
    grouped[name]=function(key,...)
     local route=assert(routes[key],'Unknown grouped setting');local fn=route.handle[name] or route.handle[name=='edit' and 'set' or 'get']
     return fn(route.key,...)
    end
   end
   for _,method in ipairs({'confirm','discard'})do
    local name=method
    grouped[name]=function(page_id)
     local route=page_routes[page_id]
     if route then return route.handle[name](route.id) end
     return base[name](page_id)
    end
   end
   if #root.pages==3 then root.pages={root.pages[2],root.pages[3],root.pages[1]}end
   if appearance then
    local pages={}
    for _,page in ipairs(root.pages)do if page.name~='General' then pages[#pages+1]=page end end
    root.pages=pages
   end
   root.handle=grouped
  end
  api.revision=api.revision+1;log('Imported '..#imported..' Bingus configuration pages')
 end
 return self
end
return M
