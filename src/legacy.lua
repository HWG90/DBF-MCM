-- Read the installed Lua registry; never replace the legacy registration API.
local M={}
-- The dedicated native blacklist page owns these controls in MCM. Keep the
-- legacy registrations intact for the original options host and saved values.
local hidden_dbf_options={
 ['native_stratagem_radial.full_color_icons']=true,
 ['native_stratagem_radial.hide_sos']=true,
 ['native_stratagem_radial.hide_eagle_rearm']=true,
}
local function group_name(key,source)
 local value=type(key)=='string' and key or (source and (source.title or source.name or source.mod))
 if type(value)=='function'then local ok,result=pcall(value);value=ok and result or nil end
 if type(value)~='string'then value='Mod '..tostring(key)end
 return value:gsub('[%c]',' '):sub(1,512)
end
local function group_keys(registry)
 local keys={};for key in pairs(registry.mods)do keys[#keys+1]=key end
 table.sort(keys,function(a,b)return group_name(a,registry.mods[a])<group_name(b,registry.mods[b])end)
 return keys
end
local function state_of(host)
 if not host or host.api~=1 or type(host.register_option)~='function' or not debug or not debug.getupvalue then return end
 for i=1,40 do local name,value=debug.getupvalue(host.register_option,i);if not name then break end
  if name=='state' and type(value)=='table' and type(value.mods)=='table' and type(value.options)=='table' and type(value.callbacks)=='table' then return value end
 end
end
local function dbf_appearance(controls,links)
 local groups={
  {1,'Selection and style',{'selection_mode_ordered','experimental_layout','appearance_preset'}},
  {1,'List visibility',{'dim_unselected','hide_blacklisted_list','hide_cooldown_list'}},
  {1,'Wheel size and position',{'wheel_size','icon_size','label_size','vertical_offset'}},
  {1,'Wheel background',{'wedge_opacity','wedge_darkness','native_opacity'}},
  {2,'Cooldown display',{'cooldown_icons','cooldown_display','short_status_placement','balance_separated_dock','track_unavailable','dock_gap','hide_closed_status'}},
  {2,'Countdown timers',{'cooldown_timers','cooldown_timer','short_timer_style','brief_timer_limit'}},
 }
 local by_key,result,used={},{},{}
 for _,c in ipairs(controls)do by_key[links[c.id].id:match('^native_stratagem_radial%.(.+)$')]=c end
 for _,group in ipairs(groups)do
  local heading=false
  for _,key in ipairs(group[3])do local c=by_key[key]
   if c then
    if not heading then result[#result+1]={type='section',label=group[2],column=group[1]};heading=true end
    c.column=group[1];result[#result+1]=c;used[c]=true
   end
  end
 end
 for _,c in ipairs(controls)do if not used[c]then c.column=2;result[#result+1]=c end end
 return result
end
function M.new(api,log,core)
 local self={};local owner,registry;local imported={};local revision=-1;local appearance_seen
 local function clear()if appearance_seen then appearance_seen.hidden=nil end;for _,id in ipairs(imported)do api.mods[id]=nil end;imported={};api.revision=api.revision+1 end
 function self.diagnostic()
  local names={};for key,source in pairs(registry and registry.mods or {})do names[#names+1]=group_name(key,source)end;table.sort(names)
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
  -- Import by displayed group identity, not raw registry key. The original
  -- Bingus host can expose several keys with the same displayed title.
  -- Keep its option objects and callbacks authoritative; merge only our view.
  local groups,by_name={},{}
  for _,source_key in ipairs(group_keys(registry))do
   local source=registry.mods[source_key]
   local name=group_name(source_key,source)
   local canonical=name:upper()
   local group=by_name[canonical]
   if not group then group={name=name,order={},seen={}};by_name[canonical]=group;groups[#groups+1]=group end
   for _,option in ipairs(source.order or {})do
    if not group.seen[option.id]then group.order[#group.order+1]=option;group.seen[option.id]=true end
   end
  end
  for index,source in ipairs(groups)do
   local name=source.name
   local direct_hud=appearance and appearance.name=='DBF-HUD'
   if not (direct_hud and (name=='DBF-HUD' or name=='DBF-HUD PLACEMENT' or name=='DBF-HUD LAYOUT EDITOR' or name=='DBF-HUD DEVELOPER')) then
   local controls={};local visual={};local links={};local pending={}
   for n,o in ipairs(source.order or {})do
    if (o.kind=='toggle' or o.kind=='slider' or o.kind=='choice') and not hidden_dbf_options[o.id] and not (name=='DBF-HUD' and appearance) then
     local key='option_'..n;local c={id=key,type=o.kind,label=o.label or o.id,description=o.description or '',default=o.default,min=o.min,max=o.max,step=o.step,choices=o.choices}
     if o.id=='native_stratagem_radial.cooldown_icons'then c.label='Appearance / Show cooldown display'end
     local dbf=name:upper()=="DIVER'S BEST FRIEND"and type(o.id)=='string'and o.id:match('^native_stratagem_radial%.')
     local appearance_label=dbf and(c.label:match('^Appearance / (.+)$')or(o.id=='native_stratagem_radial.selection_mode_ordered'and'Mode'))
     if appearance_label then c.label=appearance_label;visual[#visual+1]=c else controls[#controls+1]=c end
     links[key]=o
    end
   end
   if #controls>0 or #visual>0 or (name=='DBF-HUD' and appearance) then
    local id='bingus_'..index;local temp=core.new(nil,log)
    local pages={{id='settings',name='Settings',controls=controls}}
    if #visual>0 then pages[#pages+1]={id='appearance',name='Appearance',controls=dbf_appearance(visual,links)}end
    local handle=temp.register({id=id,name=name,description='Bingus Mod Options Menu compatibility. Confirm applies pending settings.',pages=pages})
    local mod=temp.mods[id];mod.legacy=true;local validate_set=handle.set;local validated_get=handle.get;local confirm=handle.confirm
    -- Imported child handles retain their own ownership registry even when
    -- presentation mounting hides them. Forward its invalidation to the UI.
    local imported_revision=temp.revision
    local function invalidate()
     if imported_revision~=temp.revision then imported_revision=temp.revision;api.revision=api.revision+1 end
    end
    for _,method in ipairs({'refresh_conditions','edit','discard','set_disabled','available'})do
     local original=handle[method]
     handle[method]=function(...)local a,b=original(...);invalidate();return a,b end
    end
    local native_keys={};for key,o in pairs(links)do native_keys[o.id]=key end
    function handle.get(key)
     local o=links[key];if not o then return end
     local value=pending[key];if value==nil then value=host.get(o.id)end
     return value
    end
    function handle.set(key,value)
     local o=assert(links[key],'Unknown legacy option')
     local ok,err=validate_set(key,value);if not ok then return false,err end
     value=validated_get(key);local old=host.get(o.id)
     if old==value then return true end
     ok,err=host.set(o.id,value);if not ok then return false,err end
     for _,callback in ipairs(registry.callbacks[o.id] or {})do
      local called,why=pcall(callback,value,o.id);if not called then log('Legacy callback failed: '..tostring(why))end
     end
     handle.refresh_conditions()
     return true
    end
    -- Legacy providers use their native option IDs in predicates. Read MCM
    -- drafts first so dependencies change before Confirm, not one frame later.
    for key,o in pairs(links)do
     local rules={};local has=false
     for _,name in ipairs({'enabled_if','disabled_if','visible_if'})do
      if type(o[name])=='function'then
       local predicate=o[name];rules[name]=function(get)
        return predicate(function(id)local mapped=native_keys[id];if mapped then return get(mapped)end;return host.get(id)end)
       end;has=true
      end
     end
     if o.id=='native_stratagem_radial.input_interval_ms'and native_keys['native_stratagem_radial.randomize_input_delay']and not has then
      rules.enabled_if=function(get)return not get(native_keys['native_stratagem_radial.randomize_input_delay'])end;has=true
     end
     if has then handle.set_condition(key,rules)end
    end
    mod.on_change=function(value,key) local ok,err=handle.set(key,value);if not ok then error(err) end end
    function handle.confirm(page_id)
     -- Profile owners can replace values through host.set without callbacks.
     -- Compare the draft against those current values, not registration defaults.
     for key,o in pairs(links)do mod.values[key]=host.get(o.id)end
     local ok,why=confirm(page_id)
     handle.refresh_conditions()
     return ok,why
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
      local page={id=entry.id..'_'..oldpage.id,name=entry.id=='layout_editor' and 'Layout' or (entry.id=='appearance' and oldpage.name or entry.name),category='hud',render_preview=oldpage.render_preview,preview_popout=oldpage.preview_popout==true,controls={},pending={},actions={},require_confirmation=oldpage.require_confirmation==true}
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
