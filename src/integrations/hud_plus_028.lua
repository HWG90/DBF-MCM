-- HUD+ 0.2.8 owner adapter. No native memory writes or secondary config file.
local H={}
local function member(t,k)
 if type(t)~='table'then return end
 local v=rawget(t,k);if v~=nil then return v end
 local mt=getmetatable(t);local index=type(mt)=='table'and rawget(mt,'__index')
 return type(index)=='table'and rawget(index,k)or nil
end
local function copy(t)local r={};for k,v in pairs(t)do r[k]=v end;return r end
local function validate(runtime,schema)
 local p=member(runtime,'program');local s=member(p,'settings')
 if member(runtime,'running')~=true or member(runtime,'installed')~=true or type(member(runtime,'base'))~='function'or type(member(p,'step'))~='function'or type(member(p,'close'))~='function'then return end
 local entries=member(s,'entries');local names=member(s,'by_name')
 if type(entries)~='table'or #entries<#schema or type(names)~='table'or type(member(s,'values'))~='table'then return end
 for _,key in ipairs({'begin','edit','commit','dirty','cancel','serialize'})do if type(member(s,key))~='function'then return end end
 if type(member(s,'save'))~='function'or type(member(s,'read'))~='function'then return end
 for i,e in ipairs(schema)do
  local actual=entries[i]
  if actual~=names[e.id]then return end
  for _,key in ipairs({'id','default','title','description','group','step'})do if member(actual,key)~=e[key]then return end end
  for _,key in ipairs({'choices','range'})do
   local a,b=member(actual,key),e[key]
   if type(a)~=type(b)then return end
   if b then if #a~=#b then return end;for j,value in ipairs(b)do if a[j]~=value then return end end end
  end
 end
 return p,s
end
function H.new(schema,globals,profiles)
 globals=globals or _G
 profiles=profiles or {{schema=schema,version='0.2.8',sha256='389a321ca5ed2f287b9dd7eecddbbccd6f8483ebe266f0c076ba3f0c44488eee'}}
 local self={};local root,observed,program,settings,bridge,watches,last_reason;local scans=0
 local function retire()
  if bridge then bridge.generation.retired=true end
  bridge,observed,program,settings=nil,nil,nil,nil
 end
 local function make(runtime,p,s,schema,profile)
  local public,allowed={},{}
  for _,e in ipairs(schema)do if e.title~=nil then
   allowed[e.id]=true
   public[#public+1]={id=e.id,kind=e.choices and 'choice'or 'slider',label=e.label,description=e.description_text,category=e.category,
    default=e.default,choices=e.choice_labels,min=e.range and e.range[1],max=e.range and e.range[2],step=e.range and (e.step or .01)}
  end end
  local b={api=1,name='HD2 HUD+',version=profile.version,generation={},source_archive_sha256=profile.sha256}
  function b.alive()return not b.generation.retired and member(runtime,'running')==true and member(runtime,'program')==p and member(p,'settings')==s and rawget(globals,'update')==root end
  function b.entries()local r={};for i,e in ipairs(public)do r[i]=copy(e);if e.choices then r[i].choices=copy(e.choices)end end;return r end
  function b.snapshot(token)if token~=b.generation or not b.alive()then return nil,'HUD+ owner retired'end;return copy(s.values)end
  function b.apply(changes,token)
   if token~=b.generation or not b.alive()then return false,'HUD+ owner retired'end
   if b.busy then return false,'HUD+ settings commit in progress'end
   local menu=member(p,'menu');local rows=member(menu,'rows')
   if member(rows,'content')~=nil or s:dirty()then return false,'Close or apply native HUD+ settings before editing MCM'end
   if type(changes)~='table'then return false,'Settings table required'end
   for id in pairs(changes)do if not allowed[id]then return false,'Not a public HUD+ option: '..tostring(id)end end
   local previous={editing=s.editing,begun=s.begun,base=s.base}
   local function restore()s.editing,s.begun,s.base=previous.editing,previous.begun,previous.base end
   b.busy=true
   local called,ok,why=pcall(function()
    s:begin()
    for id,value in pairs(changes)do local accepted,reason=s:edit(id,value);if not accepted then return false,reason end end
    return s:commit()
   end)
   restore();b.busy=nil
   if not called or not ok then return false,tostring(called and why or ok)end
   return true,copy(s.values)
  end
  return b
 end
 function self.poll()
  local update=rawget(globals,'update')
  local changed=update~=root
  if not changed then for _,w in ipairs(watches or {})do if member(w.runtime,'program')~=w.program or member(w.runtime,'running')~=w.running or member(w.program,'settings')~=w.settings then changed=true;break end end end
  if not changed then return bridge,last_reason end
  retire();root=update;watches={};scans=scans+1
  local queue,seen,at,visited={{fn=update,depth=0}},{},1,0
  while at<=#queue and visited<128 do
   local node=queue[at];at=at+1;local fn=node.fn
   if type(fn)=='function'and not seen[fn]then
    seen[fn]=true;visited=visited+1
    for i=1,64 do
     local name,value=debug.getupvalue(fn,i);if not name then break end
     if (name=='runtime'or name=='')and type(value)=='table'and type(member(value,'program'))=='table'then
      local p=member(value,'program');local s=member(p,'settings')
      watches[#watches+1]={runtime=value,program=p,settings=s,running=member(value,'running')}
      for _,profile in ipairs(profiles)do
       local validated,owned=validate(value,profile.schema)
       if validated then observed=value;program=validated;settings=owned;bridge=make(observed,program,settings,profile.schema,profile);last_reason=nil;return bridge end
      end
     elseif type(value)=='function'and node.depth<32 then queue[#queue+1]={fn=value,depth=node.depth+1}end
    end
   end
  end
  last_reason='Supported HUD+ owner not ready';return nil,last_reason
 end
 function self.release()retire();root=nil;watches=nil end
 function self.diagnostic()return {scans=scans,active=bridge~=nil,reason=last_reason}end
 return self
end
return H
