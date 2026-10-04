-- Presentation mounts preserve each provider's authoritative handle and storage IDs.
local M={}
function M.list(list)
 local names={};for _,mod in ipairs(list)do names[mod.name:lower()]=mod end
 local children={};local mounted={}
 for _,mod in ipairs(list)do
  local parent=mod.parent_name and names[mod.parent_name:lower()]
  if parent and parent~=mod and not parent.parent_name then
   children[parent]=children[parent] or {};children[parent][#children[parent]+1]=mod;mounted[mod]=true
  end
 end
 local result={}
 for _,mod in ipairs(list)do if not mounted[mod]then
  if not children[mod]then result[#result+1]=mod else
   local composite={};for k,v in pairs(mod)do composite[k]=v end
   composite.pages={};composite.controls={};composite.categories={}
   for _,category in ipairs(mod.categories or {})do composite.categories[#composite.categories+1]=category end
   local routes,pages={},{}
   local function add(owner,prefix)
    for _,oldpage in ipairs(owner.pages)do
     local page={};for k,v in pairs(oldpage)do page[k]=v end
     page.id=prefix..oldpage.id;page.controls={};pages[page.id]={handle=owner.handle,id=oldpage.id}
     for _,old in ipairs(oldpage.controls)do
      local c={};for k,v in pairs(old)do c[k]=v end;c.page=page;c.groups={};for _,g in ipairs(old.groups or {})do c.groups[#c.groups+1]=prefix..g end
      if c.id then local original=c.id;c.id=prefix..original;routes[c.id]={handle=owner.handle,id=original};composite.controls[c.id]=c end
      page.controls[#page.controls+1]=c
     end
     composite.pages[#composite.pages+1]=page
    end
   end
   add(mod,'')
   for _,child in ipairs(children[mod])do add(child,child.id..'__')end
   local h={id=mod.id}
   for _,method in ipairs({'get','preview','set','edit','reset','activate','queue'})do
    local name=method;h[name]=function(key,...)
     local route=assert(routes[key],'Unknown mounted setting')
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
