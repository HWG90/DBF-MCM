-- Prefer the HUD+ owner bridge; recover verified 0.2.2 closures as a fallback.
-- Discovery reads Lua closures/data; only explicit setting edits call owner methods.
local R={}
local GLOBAL='HD2HUDPlusMCMBridge'
local SOURCE='5da7897d174f5b39337df3195fe3a70d8c48d42f47903fbb83c8ec2560bf2b99'
local EXE='f5fee03dcfdb2e553a4752c283590950ac13316b376d8196aa556ff0400d5f06'
local GAME='2e2c3b7c2500646dadd5f2b4c6e0504dbb7e7896139f64cddc0d1813c718f51e'
local FINGERPRINT='2d125916'
local wrappers={inner=true,original=true,previous=true,previous_update=true,original_update=true,old_update=true,old=true,upstream=true,next_update=true,originalUpdate=true,oldUpdate=true,previousUpdate=true}
local function copy(values)local result={};for key,value in pairs(values)do result[key]=value end;return result end
local function split(value,separator)
 local out,at={},1
 while true do local found=value:find(separator,at,true);if not found then out[#out+1]=value:sub(at);return out end;out[#out+1]=value:sub(at,found-1);at=found+#separator end
end
local function decode(value)
 local out,at={},1;local escapes={['\\']='\\',t='\t',n='\n',r='\r',p='|'}
 while at<=#value do local char=value:sub(at,at)
  if char=='\\'then local next_char=value:sub(at+1,at+1);assert(escapes[next_char],'Invalid HUD+ metadata escape');out[#out+1]=escapes[next_char];at=at+2
  else out[#out+1]=char;at=at+1 end
 end
 return table.concat(out)
end
local function scalar(value)
 if value==''then return nil end
 if value=='b:true'then return true elseif value=='b:false'then return false end
 if value:sub(1,2)=='n:'then local number=tonumber(value:sub(3));assert(number and number==number and math.abs(number)<math.huge,'Invalid HUD+ metadata number');return number end
 if value:sub(1,2)=='s:'then return value:sub(3)end
 error('Invalid HUD+ metadata scalar')
end
local function tag(value)
 if value==nil then return ''elseif type(value)=='boolean'then return 'b:'..tostring(value)
 elseif type(value)=='number'then return 'n:'..string.format('%.14g',value)
 elseif type(value)=='string'then return 's:'..value end
 error('Invalid HUD+ owner schema value')
end
local function fingerprint(rows)
 local lines={}
 for _,entry in ipairs(rows)do
  local choices={};for _,value in ipairs(entry.raw_choices or {})do choices[#choices+1]=tag(value)end
  lines[#lines+1]=table.concat({entry.id,entry.kind,tag(entry.default),tag(entry.min),tag(entry.max),tag(entry.owner_step),table.concat(choices,'|')},'\t')
 end
 local value=table.concat(lines,'\n')..'\n';local a,b=1,0
 for index=1,#value do a=(a+value:byte(index))%65521;b=(b+a)%65521 end
 return string.format('%08x',b*65536+a)
end
function R.parse_metadata(data)
 assert(type(data)=='string' and #data<=65536 and not data:find('[%z\1-\8\11\12\14-\31]'),'Invalid HUD+ metadata data')
 data=data:gsub('\r\n','\n');local lines=split(data,'\n');if lines[#lines]==''then table.remove(lines)end
 local header=split(lines[1] or '','\t')
 assert(#header==8 and header[1]=='DBF-HUD-PLUS-METADATA' and header[2]=='1' and header[3]=='0.2.2','Unsupported HUD+ metadata header')
 assert(header[4]==SOURCE and header[5]==EXE and header[6]==GAME and header[7]=='41' and header[8]==FINGERPRINT,'HUD+ metadata source/schema does not match verified 0.2.2')
 local entries,ids={},{}
 for index=2,#lines do
  local fields=split(lines[index],'\t');assert(#fields==12,'Invalid HUD+ metadata row')
  local id=decode(fields[1]);assert(id:match('^[%w_.-]+$') and #id<=64 and not ids[id],'Invalid or duplicate HUD+ metadata ID');ids[id]=true
  local entry={id=id,kind=fields[2],default=scalar(decode(fields[3])),min=scalar(decode(fields[4])),max=scalar(decode(fields[5])),step=scalar(decode(fields[6])),owner_step=scalar(decode(fields[7])),label=decode(fields[8]),description=decode(fields[9]),category=decode(fields[10])}
  if fields[11]~=''then entry.choices={};for _,choice in ipairs(split(fields[11],'|'))do entry.choices[#entry.choices+1]=decode(choice)end end
  if fields[12]~=''then entry.raw_choices={};for _,choice in ipairs(split(fields[12],'|'))do entry.raw_choices[#entry.raw_choices+1]=scalar(decode(choice))end end
  assert(#entry.label<=512 and #entry.description<=4096 and #entry.category<=512,'HUD+ metadata text exceeds limits')
  assert(entry.kind=='slider' or entry.kind=='choice' or entry.kind=='toggle','Unknown HUD+ metadata kind')
  if entry.kind=='slider'then assert(type(entry.min)=='number' and type(entry.max)=='number' and entry.max>entry.min and type(entry.step)=='number' and entry.step>0 and entry.step<=entry.max-entry.min,'Invalid HUD+ slider metadata')
  elseif entry.kind=='choice'then assert(entry.choices and entry.raw_choices and #entry.choices==#entry.raw_choices,'Invalid HUD+ choice metadata')end
  entries[#entries+1]=entry
 end
 assert(#entries==41 and fingerprint(entries)==FINGERPRINT,'HUD+ option schema changed')
 return {entries=entries,source_archive_sha256=SOURCE,pin_exe=EXE,pin_game=GAME,fingerprint=FINGERPRINT}
end
function R.read_metadata(path)
 local file,err=io.open(path,'rb');if not file then return nil,err or 'HUD+ metadata sidecar is missing'end
 local data=file:read(65537);file:close();local ok,result=pcall(R.parse_metadata,data)
 return ok and result or nil,not ok and tostring(result) or nil
end
-- Do not execute an unknown __index function while checking candidate ownership.
local function member(value,key)
 if type(value)~='table'then return nil end
 local found=rawget(value,key);if found~=nil then return found end
 local mt=getmetatable(value);local index=type(mt)=='table' and rawget(mt,'__index') or nil
 return type(index)=='table' and rawget(index,key) or nil
end
local function upvalue(fn,key)
 if type(fn)~='function' or not debug or type(debug.getupvalue)~='function'then return nil end
 for index=1,64 do local ok,name,value=pcall(debug.getupvalue,fn,index);if not ok or name==nil then break end;if name==key then return value end end
end
local function lua_function(fn)
 if type(fn)~='function' or not debug or type(debug.getinfo)~='function'then return false end
 local ok,info=pcall(debug.getinfo,fn,'S');return ok and type(info)=='table' and (info.what=='Lua' or info.what=='main')
end
local function validate_worker(worker,metadata)
 if type(worker)~='table' or type(metadata)~='table' or metadata.fingerprint~=FINGERPRINT or fingerprint(metadata.entries or {})~=FINGERPRINT then return false,'metadata fingerprint' end
 local baked=member(worker,'baked');local pin=member(baked,'pin')
 if member(pin,'exe')~=EXE or member(pin,'game')~=GAME or type(member(baked,'screens'))~='table' then return false,'owner pins/screens' end
 local options=member(worker,'options');local order=member(options,'order');local kinds=member(options,'kinds');local values=member(options,'values')
 if type(order)~='table' or #order~=41 or type(kinds)~='table' or type(values)~='table' then return false,'owner option table/count' end
 for _,method in ipairs({'begin','edit','apply','dirty'})do if type(member(options,method))~='function'then return false,'owner method '..method end end
 if type(member(worker,'apply_options'))~='function'then return false,'owner apply_options method' end
 for index,expected in ipairs(metadata.entries)do
  if rawget(order,index)~=expected.id then return false,'owner option order at '..index end
  local entry=rawget(kinds,expected.id);local range=member(entry,'range');local choices=member(entry,'choices');local option=member(entry,'option')
  if member(entry,'id')~=expected.id or member(entry,'default')~=expected.default then return false,'owner default '..expected.id end
  local kind=range and 'slider' or (choices and 'choice' or 'toggle');if kind~=expected.kind then return false,'owner kind '..expected.id end
  if member(range,1)~=expected.min or member(range,2)~=expected.max or member(option,'step')~=expected.owner_step then return false,'owner range/step '..expected.id end
  if expected.raw_choices then
   if type(choices)~='table' or #choices~=#expected.raw_choices then return false,'owner choice count '..expected.id end
   for position,value in ipairs(expected.raw_choices)do if rawget(choices,position)~=value then return false,'owner enum '..expected.id end end
  elseif choices~=nil then return false,'unexpected owner enum '..expected.id end
 end
 return true
end
local function workers_from(fn,metadata)
 local queue,seen,workers,at,visited={{fn=fn,depth=0}},{},{},1,0;local rejected
 while at<=#queue and visited<12 do local node=queue[at];at=at+1
  if lua_function(node.fn) and not seen[node.fn]then
   seen[node.fn]=true;visited=visited+1
   for index=1,64 do
    local ok,name,value=pcall(debug.getupvalue,node.fn,index);if not ok or name==nil then break end
    if (name=='worker' or name=='') and type(value)=='table'then
     local valid,why=validate_worker(value,metadata)
     if valid then workers[value]=true elseif member(value,'baked') or member(value,'options')then rejected=rejected or why end
    elseif node.depth<4 and lua_function(value)then queue[#queue+1]={fn=value,depth=node.depth+1}end
   end
  end
 end
 return workers,rejected
end
local function candidate(hook,metadata)
 local driver=member(hook,'driver')
 if member(driver,'VERSION')~='boot-state-v1' or member(driver,'installed')~=true or member(driver,'result')~=true or member(driver,'armed')==false or member(driver,'hook')~=hook then return nil,nil,'hook shape' end
 local frame,close=member(driver,'frame'),member(driver,'close');local run=upvalue(frame,'run');local worker=upvalue(run,'worker')
 if worker~=nil and upvalue(frame,'worker')==worker and upvalue(close,'worker')==worker and validate_worker(worker,metadata)then return worker,driver end
 -- Stripped bytecode has anonymous upvalues. Require one identical, fully
 -- validated worker reachable independently from both owned callbacks.
 local frames,frame_rejection=workers_from(frame,metadata);local closes,close_rejection=workers_from(close,metadata);local found
 for value in pairs(frames)do if closes[value]then if found then return nil,nil,'ambiguous workers'end;found=value end end
 if found then return found,driver end
 return nil,nil,frame_rejection or close_rejection or 'worker callback ownership'
end
function R.find(update,metadata)
 if not debug or type(debug.getupvalue)~='function' or type(debug.getinfo)~='function'then return nil,'Lua closure inspection is unavailable'end
 local queue,seen,at,visited={{fn=update,depth=0}},{},1,0
 local watches,watched={},{}
 local diagnostic={nodes=0,hooks=0,schema_rejected=0,c_skipped=0,depth_limited=0,node_limit=128}
 local limit=128
 while at<=#queue and visited<limit do
  local node=queue[at];at=at+1
  if lua_function(node.fn) and not seen[node.fn]then
   seen[node.fn]=true;visited=visited+1
   diagnostic.nodes=visited
   local priority,deferred={},{}
   for index=1,64 do
    local ok,name,value=pcall(debug.getupvalue,node.fn,index);if not ok or name==nil then break end
    if type(value)=='table'then
     local observed=member(value,'driver')
     local known=member(observed,'VERSION')=='boot-state-v1'
     local anonymous_shape=known and member(observed,'hook')==value and member(observed,'installed')==true and member(observed,'result')==true
     local eligible=anonymous_shape
     if eligible and not watched[value]then
      diagnostic.hooks=diagnostic.hooks+1
      watched[value]=true;watches[#watches+1]={hook=value,driver=observed,armed=member(observed,'armed'),result=member(observed,'result')}
      local worker,driver,why=candidate(value,metadata)
      if worker then return worker,driver,value,watches,diagnostic end
      diagnostic.schema_rejected=diagnostic.schema_rejected+1;diagnostic.last_rejection=why
     end
     local inner=member(value,'outer_inner')
     if eligible and node.depth<32 and lua_function(inner)then priority[#priority+1]={fn=inner,depth=node.depth+1}end
    elseif type(value)=='function'then
     if not lua_function(value)then diagnostic.c_skipped=diagnostic.c_skipped+1
     elseif node.depth<32 then
      local target=(wrappers[name] or name=='') and priority or deferred
      target[#target+1]={fn=value,depth=node.depth+1}
     else diagnostic.depth_limited=diagnostic.depth_limited+1 end
    end
   end
   for _,edge in ipairs(priority)do queue[#queue+1]=edge end
   for _,edge in ipairs(deferred)do queue[#queue+1]=edge end
  end
  if visited==128 and at<=#queue and limit==128 then limit=256;diagnostic.node_limit=256 end
 end
 diagnostic.budget_exhausted=visited>=limit and at<=#queue
 local reason=string.format('Verified HUD+ 0.2.2 update owner not found (nodes=%d limit=%d hooks=%d schema_rejected=%d depth_limited=%d budget_exhausted=%s%s)',visited,limit,diagnostic.hooks,diagnostic.schema_rejected,diagnostic.depth_limited,tostring(diagnostic.budget_exhausted),diagnostic.last_rejection and (' last='..diagnostic.last_rejection) or '')
 return nil,reason,nil,watches,diagnostic
end
function R.bridge(worker,driver,hook,metadata,current)
 assert(validate_worker(worker,metadata),'HUD+ owner schema does not match verified 0.2.2')
 local bridge={api=1,name='HD2 HUD+',version='0.2.2',generation={},source_archive_sha256=SOURCE}
 function bridge.alive()
  return not bridge.generation.retired and member(hook,'driver')==driver and member(driver,'hook')==hook and member(driver,'armed')~=false and member(driver,'result')==true and not member(worker,'failed') and (not current or current())
 end
 function bridge.entries()
  local result={};for _,entry in ipairs(metadata.entries)do local row=copy(entry);if row.choices then row.choices=copy(row.choices)end;if row.raw_choices then row.raw_choices=copy(row.raw_choices)end;result[#result+1]=row end;return result
 end
 function bridge.native_menu(token)
  if (token==nil or token==bridge.generation) and bridge.alive()then return member(worker,'menu')end
 end
 function bridge.snapshot(token)
  if token~=bridge.generation or not bridge.alive()then return nil,'HUD+ bridge was retired'end
  return copy(member(member(worker,'options'),'values'))
 end
 function bridge.apply(changes,token)
  if token~=bridge.generation or not bridge.alive()then return false,'HUD+ bridge was retired'end
  if type(changes)~='table'then return false,'HUD+ changes must be a table'end
  if bridge.busy then return false,'HUD+ settings are already being saved'end
  local options=member(worker,'options');local menu=member(worker,'menu')
  if member(menu,'view') or options:dirty()then return false,'Close or apply the native HUD+ settings before editing MCM'end
  local previous={pending=options.pending,base=options.base,begun=options.begun,extra=options.extra}
  local function restore()options.pending,options.base,options.begun,options.extra=previous.pending,previous.base,previous.begun,previous.extra end
  options:begin()
  for id,value in pairs(changes)do local ok,err=options:edit(id,value);if not ok then restore();return false,err or 'HUD+ value was rejected'end end
  bridge.busy=true;local invoked,ok,err=pcall(member(worker,'apply_options'),worker);bridge.busy=nil
  if not invoked or not ok then restore();return false,tostring(invoked and err or ok)end
  options.pending,options.base,options.begun=nil,nil,nil
  return true,copy(options.values)
 end
 return bridge
end
function R.new(folder,log,options)
 options=options or {};log=log or function()end
 local globals=options.globals or _G;local metadata,metadata_error=options.metadata,nil
 if not metadata then metadata,metadata_error=R.read_metadata(folder..'/hud_plus_labels.tsv')end
 local self={};local published,worker,driver,hook,last_update,last_error
 local loaded=options.loaded or package.loaded
 local function external_bridge()
  local global=rawget(globals,GLOBAL)
  if global~=nil and global~=published then return global end
  local product=rawget(loaded,'mods/hd2_hud/hd2_hud_plus')
  return type(product)=='table' and rawget(product,'mcm_bridge') or nil
 end
 local watches={}
 local inspected_update,inspected_worker,inspected_driver,inspected_hook,inspected_watches
 local function watches_unchanged(observed)
  for _,watch in ipairs(observed or {})do local owner=member(watch.hook,'driver')
   if owner~=watch.driver or member(owner,'armed')~=watch.armed or member(owner,'result')~=watch.result then return false end
  end
  return true
 end
 local function inspect(update)
  inspected_update=update
  inspected_worker,inspected_driver,inspected_hook,inspected_watches=R.find(update,metadata)
  return inspected_worker,inspected_driver,inspected_hook,inspected_watches
 end
 local function current()
  if rawget(globals,GLOBAL)~=published then return false end
  local update=rawget(globals,'update');if update==last_update then return true end
  if update~=inspected_update or not watches_unchanged(inspected_watches)then inspect(update)end
  if inspected_worker==worker and inspected_driver==driver and inspected_hook==hook then
   last_update=update;watches=inspected_watches or {};last_error=nil;return true
  end
  return false
 end
 local function retire()
  if published then published.generation.retired=true;if rawget(globals,GLOBAL)==published then rawset(globals,GLOBAL,nil)end end
  published,worker,driver,hook=nil,nil,nil,nil
 end
 function self.poll()
  local existing=external_bridge()
  if existing~=nil then return existing end
  if not metadata then return nil,metadata_error end
  local update=rawget(globals,'update')
  if update==last_update and published and published.alive()then return published end
  if update==last_update and not published and last_error then
   if watches_unchanged(watches)then return nil,last_error end
  end
  local found,owner,owned_hook,observed
  if update==inspected_update and watches_unchanged(inspected_watches)then
   found,owner,owned_hook,observed=inspected_worker,inspected_driver,inspected_hook,inspected_watches
  else found,owner,owned_hook,observed=inspect(update)end
  watches=observed or {}
  last_update=update
  if not found then retire();last_error=owner;return nil,last_error end
  if found==worker and owner==driver and owned_hook==hook and published then last_error=nil;return published end
  retire();worker,driver,hook=found,owner,owned_hook
  published=R.bridge(worker,driver,hook,metadata,current)
  rawset(globals,GLOBAL,published);last_error=nil;pcall(log,'HUD+ 0.2.2 live owner recovered (41 settings)')
  return published
 end
 function self.release()
  retire();last_update=nil;last_error=nil;watches={}
  inspected_update,inspected_worker,inspected_driver,inspected_hook,inspected_watches=nil,nil,nil,nil,nil
 end
 function self.diagnostic()
  if external_bridge()~=nil then return 'HUD+ owner-provided bridge available'end
  return published and 'HUD+ live owner bridge active' or (last_error or metadata_error or 'HUD+ live owner bridge waiting')
 end
 return self
end
return R
