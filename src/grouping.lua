-- Presentation mounts preserve each provider's authoritative handle and storage IDs.
local M={}
function M.list(list)
 local names,ids={},{};for _,mod in ipairs(list)do names[mod.name:lower()]=mod;ids[mod.id]=mod end
 local children={};local mounted={}
 for _,mod in ipairs(list)do
  local parent=mod.parent_name and names[mod.parent_name:lower()]
  if parent and parent~=mod and not parent.parent_name then
   children[parent]=children[parent] or {};children[parent][#children[parent]+1]=mod;mounted[mod]=true
  end
 end
 local result={}
 for _,mod in ipairs(list)do if not mounted[mod]then
  local references=false;for _,page in ipairs(mod.pages)do for _,c in ipairs(page.controls)do if c.source_mod_id then references=true end end end
  if not children[mod]and not references then result[#result+1]=mod else
   local composite={};for k,v in pairs(mod)do composite[k]=v end
   composite.pages={};composite.controls={};composite.categories={}
   for _,category in ipairs(mod.categories or {})do composite.categories[#composite.categories+1]=category end
   local routes,pages={},{}
   local function add(owner,prefix)
    for _,oldpage in ipairs(owner.pages)do
     local page={};for k,v in pairs(oldpage)do page[k]=v end
     page.id=prefix..oldpage.id;page.controls={};pages[page.id]={handle=owner.handle,id=oldpage.id}
     for _,old in ipairs(oldpage.controls)do
      local source=owner;if old.source_mod_id then source=ids[old.source_mod_id]end
      if source and (not old.source_mod_id or source.controls[old.source_control_id])then
      local c={};for k,v in pairs(old)do c[k]=v end;c.page=page;c.groups={};for _,g in ipairs(old.groups or {})do c.groups[#c.groups+1]=prefix..g end
      if c.id then local original=c.id;c.id=prefix..original;routes[c.id]={handle=source.handle,id=old.source_control_id or original};composite.controls[c.id]=c end
      page.controls[#page.controls+1]=c
      end
     end
     composite.pages[#composite.pages+1]=page
    end
   end
   add(mod,'')
   for _,child in ipairs(children[mod]or {})do add(child,child.id..'__')end
   local h={id=mod.id}
   for _,method in ipairs({'get','preview','set','edit','reset','activate','queue'})do
    local name=method;h[name]=function(key,...)
     local route=assert(routes[key],'Unknown mounted setting')
     local control=composite.controls[key]
     if control.source_mod_id and (name=='set'or name=='edit'or name=='reset'or name=='activate'or name=='queue')then assert(not control.disabled,'Setting unavailable')end
     local fn=route.handle[name] or route.handle[name=='edit' and 'set' or 'get']
     return fn(route.id,...)
    end
   end
   for _,method in ipairs({'confirm','discard'})do
    local name=method;h[name]=function(page_id)local route=assert(pages[page_id],'Unknown mounted page');return route.handle[name](route.id)end
   end
   composite.handle=h;result[#result+1]=composite
  end
 end end
 return result
end
return M
