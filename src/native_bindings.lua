-- MBM native action editor. No VK polling is substituted for mod activation.
-- MCM persists keyboard edits by stable binding ID; native-page edits win.
-- Native layout/fingerprint follow CowboyBingus ModBindingsMenu (0BSD).
local N={}
local function up(fn,key)
 if type(fn)~='function'or not debug then return end
 for i=1,64 do local name,value=debug.getupvalue(fn,i);if not name then return end;if name==key then return value end end
end
local function number(v,lo,hi)return type(v)=='number'and v==v and v%1==0 and v>=lo and v<=hi end
local function word(s,at)
 at=at or 0;local a,b,c,d=s:byte(at+1,at+4);if not d then return end
 return a+b*256+c*65536+d*16777216
end
local function packed(v)return string.char(v%256,math.floor(v/256)%256,math.floor(v/65536)%256,math.floor(v/16777216)%256)end
local function put(s,at,v)return s:sub(1,at)..packed(v)..s:sub(at+5)end
local function pointer(s)return s and word(s)+word(s,4)*4294967296 end
local function address(v)return number(v,65536,140737488355327)and v%8==0 end
-- Build 25480438's native keyboard namespace starts 49 entries after the SDK
-- VK namespace. Verified native defaults: Tab/F1/F5-F8; live native captures:
-- F2=162, A=114, and the saved Quote mapping=271. Unsupported SDK names refuse.
function N.keyboard_codec(keyboard)
 local function label(vk)
  if not number(vk,8,255)or type(keyboard)~='table'or type(keyboard.button_name)~='function'then return end
  local ok,name=pcall(keyboard.button_name,vk)
  if not ok or type(name)~='string'or name==''or #name>64 or name:find('[%c]')then return end
  return name
 end
 return function(vk)
  if not label(vk)then return nil,'This keyboard key is not supported by the game' end
  return vk+49
 end,function(code)
  local name=number(code,57,304)and label(code-49)
  if not name then return nil end
  if #name==1 or name:match('^f%d+$')then return name:upper()end
  return name:gsub('(%a)([%w]*)',function(first,rest)return first:upper()..rest end)
 end
end
function N.fingerprint(bytes)
 local bit=require('bit');local hash=bit.tobit(2166136261)
 local function mix(v)hash=bit.bxor(hash,v);hash=bit.tobit(hash*403+bit.lshift(hash,24))end
 local count=word(bytes,4);mix(count)
 for i=0,count-1 do local at=8+i*20;mix(word(bytes,at));mix(word(bytes,at+4)%65536)
  mix(word(bytes,at+8));mix(word(bytes,at+12));mix(word(bytes,at+16))end
 return hash
end
local function keyboard(bytes)
 if type(bytes)~='string'or #bytes~=328 then return nil,'Native record unavailable' end
 local count=word(bytes,4);if not number(count,0,16)then return nil,'Native mapping count changed' end
 local result={count=count,key=-1}
 for i=0,count-1 do
  local at=8+i*20;local flags=word(bytes,at)
  if flags%16==3 then
   if result.at or math.floor(flags/16)%16~=4 or word(bytes,at+12)~=0 then
    return nil,'Use the native MODS page for multiple-key or chord bindings'
   end
   result.at=at;result.key=word(bytes,at+4)%65536
  end
 end
 return result
end
function N.replace_keyboard(bytes,code)
 local current,why=keyboard(bytes);if not current then return nil,why end
 if not number(code,0,65535)then return nil,'Unsupported native key' end
 if current.at then
  -- Preserve device flags, trigger, threshold, controller/mouse bytes and parser padding.
  return put(bytes,current.at+4,math.floor(word(bytes,current.at+4)/65536)*65536+code),current.key
 end
 if current.count>=16 then return nil,'Native binding has no free mapping slot' end
 local at=8+current.count*20
 local mapping=packed(67)..packed(code)..packed(0)..packed(0)..packed(0)
 local next_bytes=bytes:sub(1,at)..mapping..bytes:sub(at+21)
 return put(next_bytes,4,current.count+1),-1
end

-- The memory factory is injected by the adapter. Native writes follow either
-- an explicit capture or a persisted edit whose original baseline still matches.
function N.windows(options)
 local ffi=options.ffi or require('ffi');local memory=assert(options.memory)
 local build=assert(options.build);local kernel=options.kernel or ffi.load('kernel32')
 if not pcall(function()return kernel.dbfmcm_mbm_WriteProcessMemory end)then
  ffi.cdef[[
   int dbfmcm_mbm_WriteProcessMemory(void *,void *,const void *,size_t,size_t *) __asm__("WriteProcessMemory");
   void *dbfmcm_mbm_GetCurrentProcess(void) __asm__("GetCurrentProcess");
  ]]
 end
 local done=ffi.new('size_t[1]');local process=kernel.dbfmcm_mbm_GetCurrentProcess()
 local function read(at,size)
  if not address(at)then return nil end
  return memory.read(ffi.cast('const void *',at),size)
 end
 local function write(at,bytes)
  if not memory.writable_data(ffi.cast('void *',at),#bytes)then return false end
  done[0]=0
  return kernel.dbfmcm_mbm_WriteProcessMemory(process,ffi.cast('void *',at),bytes,#bytes,done)~=0 and tonumber(done[0])==#bytes
 end
 return function(host)
  if type(host)~='table'or host.api~=1 or host.version~=3 or host.capacity~=36 then return nil,'Unsupported MBM provider' end
  local state=up(host.register_binding,'state');local header=up(host.is_down,'live_header')
  local sweep=up(host.is_down,'sweep_bindings')
  if type(state)~='table'or up(host.is_down,'state')~=state or up(header,'state')~=state or
   up(sweep,'state')~=state or up(host.is_down,'INPUT_OWNER_PTR_RVA')~=0x347cf18 or
   type(state.registry)~='table'or type(state.buckets)~='table'or type(state.swept_counts)~='table'or
   type(state.code_order)~='table' then
   return nil,'MBM native editor layout is unavailable'
  end
  local verified,why=memory.verify_build(build);if not verified then return nil,why end
  local base=memory.address(memory.module('game.dll'))
  if not address(base)or state.base~=base then return nil,'MBM module identity differs' end
  local self={}
  function self.page_open()return state.page_open==true end
  function self.snapshot(record)
   local valid_code=(record.group==9 and number(record.action,0,11))or
    (record.group==10 and number(record.action,0,17))or
    (record.group==11 and number(record.action,0,3))or
    (record.group==12 and number(record.action,0,1))
   if not valid_code or record.code~=record.group*65536+record.action or
    state.registry[record.id]~=record or not state.build_rows or not state.code_order[record.code]then return nil,'Native binding is not ready' end
   local book=state.assignments
   if type(book)~='table'or type(book.actions)~='table'or type(book.actions[record.code])~='table'or book.actions[record.code].clear then
    return nil,'Waiting for MBM to initialize this action'
   end
   local owner=pointer(read(base+0x347cf18,8));if not address(owner)then return nil,'Native input owner unavailable' end
   local vector=read(owner+686800,12);local start=pointer(vector)
   if not address(start)or word(vector,8)~=256 then return nil,'Native mapping vector changed' end
   local bucket=state.buckets[record.code];local bytes
   if address(bucket)and bucket>=start and bucket<start+256*328 and (bucket-start)%328==0 then bytes=read(bucket,328) end
   if not bytes or word(bytes)~=record.code then
    local all=read(start,256*328);if not all then return nil,'Native mapping vector unavailable' end
    for i=0,255 do if word(all,i*328)==record.code then bucket=start+i*328;bytes=all:sub(i*328+1,(i+1)*328);break end end
   end
   if not bytes or word(bytes)~=record.code or not keyboard(bytes)then return nil,'Native keyboard binding unavailable' end
   -- Refreshes outside the native page may still be awaiting MBM's sweep.
   if book.actions[record.code].left~=N.fingerprint(bytes)then return nil,'Waiting for MBM to finish refreshing bindings' end
   return {record=record,owner=owner,vector=start,bucket=bucket,bytes=bytes,book=book,action=book.actions[record.code]}
  end
  local function current(token,bytes)
   if state.registry[token.record.id]~=token.record or state.assignments~=token.book or
    token.book.actions[token.record.code]~=token.action or state.page_open then return false end
   local owner=pointer(read(base+0x347cf18,8));local vector=owner and read(owner+686800,12)
   return owner==token.owner and pointer(vector)==token.vector and word(vector,8)==256 and read(token.bucket,328)==bytes
  end
  function self.write(token,bytes)
   if #bytes~=328 or word(bytes)~=token.record.code or not keyboard(bytes)or not current(token,token.bytes)then return false,'Native owner or binding changed' end
   if not memory.writable_data(ffi.cast('void *',token.bucket),328)then return false,'Native mapping is not writable' end
   local payload_ok=write(token.bucket+8,bytes:sub(9))
   local intermediate=token.bytes:sub(1,8)..bytes:sub(9)
   local count_ok=payload_ok and current(token,intermediate)and write(token.bucket+4,bytes:sub(5,8))
   if not count_ok or not current(token,bytes)then
    -- Restore only while this is still the same action in the current vector.
    local owner=pointer(read(base+0x347cf18,8));local vector=owner and read(owner+686800,12)
    local observed=read(token.bucket,328)
    local partial=token.bytes:sub(1,8)..bytes:sub(9)
    if owner==token.owner and pointer(vector)==token.vector and word(vector,8)==256 and
     (observed==token.bytes or observed==bytes or observed==partial)then
     write(token.bucket+8,token.bytes:sub(9));write(token.bucket+4,token.bytes:sub(5,8))
    end
    return false,'Native binding write/readback failed'
   end
   token.bytes=bytes;return true
  end
  function self.acknowledge(token)
   if not current(token,token.bytes)then return false,'Native binding changed before acknowledgement' end
   token.action.left=N.fingerprint(token.bytes);token.book.dirty=true
   state.swept_counts[token.record.code]=word(token.bytes,4)
   return true
  end
  return self
 end
end

local function store_key(id)return 'b_'..id:gsub('.',function(c)return string.format('%02x',c:byte())end)end
local function clone(t)local r={};for k,v in pairs(t)do r[k]=v end;return r end
function N.new(options)
 local store=assert(options.store);local codec=assert(options.key_code);local make_backend=assert(options.backend)
 local values=store.load('mbm_bindings')or {};local owner,backend,reason;local visits={}
 local self={}
 local function save(next_values)
  local called,ok,why=pcall(store.save,'mbm_bindings',next_values)
  if not called or ok~=true then return false,tostring(called and why or ok)end
  values=next_values;return true
 end
 function self.attach(host)
  if owner==host and backend then return end
  if owner~=host then visits={}end
  owner=host;backend=nil
  local called,b,why=pcall(make_backend,host)
  backend=called and b or nil;reason=called and why or b
 end
 function self.available(record)
  if not backend then return false,tostring(reason or 'Native rebinding unavailable')end
  if backend.page_open()then return false,'Close the native bindings page before rebinding in MCM'end
  local token,why=backend.snapshot(record);return token~=nil,why
 end
 function self.bind(record,vk)
  local available,why=self.available(record);if not available then return false,why end
  local native,codec_error=codec(vk);if not number(native,0,65535)then return false,codec_error or 'This keyboard key is not supported'end
  local token,error_text=backend.snapshot(record);if not token then return false,error_text end
  local original=token.bytes;local edited,previous=N.replace_keyboard(original,native);if not edited then return false,previous end
  local written,write_error=backend.write(token,edited);if not written then return false,write_error end
  local key=store_key(record.id);local baseline=N.fingerprint(original)
  local prior=values[key]
  if type(prior)=='string'then
   local _,old_desired,old_previous,old_baseline=prior:match('^(%d+) (%d+) (%-?%d+) (%-?%d+)$')
   if tonumber(old_desired)==previous and number(tonumber(old_previous),-1,65535)and number(tonumber(old_baseline),-2147483648,2147483647)then
    previous,baseline=tonumber(old_previous),tonumber(old_baseline)
   end
  end
  local next_values=clone(values);next_values[key]=tostring(vk)..' '..tostring(native)..' '..tostring(previous)..' '..tostring(baseline)
  local saved,save_error=save(next_values)
  if not saved then
   local restored,restore_error=backend.write(token,original)
   return false,'Could not save binding: '..tostring(save_error)..(restored and ''or '; restore pending: '..tostring(restore_error))
  end
  local acknowledged,ack_error=backend.acknowledge(token)
  if not acknowledged then return false,'Binding saved; native acknowledgement pending: '..tostring(ack_error)end
  return true,'Binding saved'
 end
 function self.poll(host,records)
  self.attach(host);if not backend then return end
  if backend.page_open()then
   for _,record in ipairs(records or {})do visits[record.id]=true end
   return
  end
  for _,record in ipairs(records or {})do
   local key=store_key(record.id);local value=values[key]
   if type(value)=='string'then
    local vk,desired,previous,baseline=value:match('^(%d+) (%d+) (%-?%d+) (%-?%d+)$')
    if not vk then vk,desired,previous=value:match('^(%d+) (%d+) (%-?%d+)$')end
    vk,desired,previous,baseline=tonumber(vk),tonumber(desired),tonumber(previous),tonumber(baseline)
    local token=vk and backend.snapshot(record);local current=token and keyboard(token.bytes)
    if current and number(desired,0,65535)and number(previous,-1,65535)and codec(vk)==desired then
     if current.key~=desired then
      if visits[record.id] or current.key~=previous or (baseline and N.fingerprint(token.bytes)~=baseline)then
       -- A later game-native edit is authoritative, including clearing a key.
       local next_values=clone(values);next_values[key]=nil
       local ok,why=save(next_values);if not ok and options.log then options.log('Could not retire native override: '..tostring(why))end
      else
       local edited=N.replace_keyboard(token.bytes,desired)
       if edited then local ok=backend.write(token,edited);if ok then backend.acknowledge(token)end end
      end
     end
     visits[record.id]=nil
    end
   end
  end
 end
 function self.release()owner,backend=nil,nil end
 return self
end
return N
