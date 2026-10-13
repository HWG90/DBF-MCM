-- Isolated MBM transaction contracts. No game attachment or native calls.
local N=dofile('src/native_bindings.lua')
local bit=require('bit')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function pack(v)return string.char(v%256,math.floor(v/256)%256,math.floor(v/65536)%256,math.floor(v/16777216)%256)end
local function word(s,at)local a,b,c,d=s:byte(at+1,at+4);return a+b*256+c*65536+d*16777216 end
local function mapping(flags,key,trigger,combine,threshold)
 return pack(flags)..pack(key)..pack(trigger)..pack(combine)..pack(threshold)
end
local keyboard=mapping(0xa5060043,0xabcd00a1,6,0,0x3e4ccccd)
local mouse=mapping(0x00190042,0x99120003,25,1,0x3f000000)
local pad=mapping(0x00550045,0x77330016,85,2,0x3f800000)
local function record(mappings)
 local used=table.concat(mappings);local tail={}
 for i=#used+1,320 do tail[#tail+1]=string.char((i*29)%256)end
 return pack(655366)..pack(#mappings)..used..table.concat(tail)
end
local function replace_word(s,at,value)return s:sub(1,at)..pack(value)..s:sub(at+5)end
local function clone(t)local next={};for k,v in pairs(t)do next[k]=v end;return next end
local function key(id)return 'b_'..id:gsub('.',function(c)return string.format('%02x',c:byte())end)end
local function fixture(options)
 options=options or {}
 local f={bytes=options.bytes or record({mouse,keyboard,pad}),record={id='firstperson.toggle',code=655366},
  host={supported=true},saved=clone(options.saved or {}),saves=0,writes=0,acks=0,page=false,blocked=false}
 local store={}
 function store.load(name)assert(name=='mbm_bindings');return clone(f.saved)end
 function store.save(name,values)
  assert(name=='mbm_bindings');f.saves=f.saves+1
  if f.fail_save then return false,'disk full'end
  f.saved=clone(values);return true
 end
 local backend={}
 function backend.page_open()return f.page end
 function backend.snapshot(r)
  assert(r==f.record)
  if f.blocked then return nil,'Waiting for MBM sweep'end
  return {record=r,bytes=f.bytes}
 end
 function backend.write(token,bytes)
  f.writes=f.writes+1
  if f.fail_write then return false,'write refused'end
  if token.bytes~=f.bytes then return false,'stale snapshot'end
  f.bytes=bytes;token.bytes=bytes;return true
 end
 function backend.acknowledge(token)
  assert(token.bytes==f.bytes);f.acks=f.acks+1;f.left=N.fingerprint(f.bytes);return true
 end
 local function codec(vk)return ({[112]=161,[116]=165,[117]=166})[vk],'Unsupported test key'end
 f.service=N.new({store=store,key_code=codec,backend=function(host)
  if not host or not host.supported then return nil,'Unsupported MBM provider'end
  return backend
 end})
 f.service.attach(f.host)
 return f
end
local function windows_fixture()
 local f={base=0x10000000,owner=0x20000000,vector=0x30000000,writable=true,writes={},map_count=256}
 f.bucket=f.vector+328*2;f.bytes=record({mouse,keyboard,pad})
 f.record={id='firstperson.toggle',code=655366,group=10,action=6}
 f.state={base=f.base,build_rows=true,registry={[f.record.id]=f.record},buckets={[f.record.code]=f.bucket},
  swept_counts={[f.record.code]=3},code_order={[f.record.code]=12},assignments={actions={[f.record.code]={left=N.fingerprint(f.bytes)}}}}
 local state=f.state;local INPUT_OWNER_PTR_RVA=0x347cf18
 local function live_header(r)return state.registry[r.id]end
 local function sweep_bindings()return state.assignments end
 f.host={api=1,version=3,capacity=36}
 function f.host.register_binding(id)return state.registry[id]end
 function f.host.is_down(id)
  if state.registry[id]and INPUT_OWNER_PTR_RVA then sweep_bindings();return live_header(state.registry[id])end
 end
 local memory={}
 function memory.verify_build()return true end
 function memory.module(name)assert(name=='game.dll');return f.base end
 function memory.address(at)return at end
 function memory.writable_data()return f.writable end
 function memory.read(at,size)
  if at==f.base+0x347cf18 and size==8 then return pack(f.owner)..pack(0)end
  if at==f.owner+686800 and size==12 then return pack(f.vector)..pack(0)..pack(f.map_count)end
  if at==f.bucket and size==328 then return f.bytes end
  if at==f.vector and size==256*328 then
   return string.rep('\0',2*328)..f.bytes..string.rep('\0',(256-3)*328)
  end
 end
 local kernel={}
 function kernel.dbfmcm_mbm_GetCurrentProcess()return 1 end
 function kernel.dbfmcm_mbm_WriteProcessMemory(process,at,bytes,size,done)
  assert(process==1 and #bytes==size)
  f.writes[#f.writes+1]={at=at,bytes=bytes}
  if f.fail_count and at==f.bucket+4 then return 0 end
  if at==f.bucket+8 then f.bytes=f.bytes:sub(1,8)..bytes
  elseif at==f.bucket+4 then f.bytes=f.bytes:sub(1,4)..bytes..f.bytes:sub(9)
  else error('unexpected native write address')end
  done[0]=size
  if f.change_owner_after_payload and at==f.bucket+8 then f.owner=f.owner+0x1000 end
  return 1
 end
 local fake_ffi={load=function()return kernel end,new=function()return {[0]=0}end,cast=function(_,value)return value end}
 f.backend=assert(N.windows({ffi=fake_ffi,memory=memory,build={}})(f.host))
 return f
end

test('keyboard replacement preserves other devices and every non-key byte',function()
 local before=record({mouse,keyboard,pad});local after,previous=N.replace_keyboard(before,165)
 assert(previous==161 and #after==328)
 local at=8+20+4
 assert(after==replace_word(before,at,0xabcd00a5),'flags, trigger, threshold, padding or other devices changed')
 assert(word(after,4)==3)
end)
test('native fingerprint ignores parser padding but detects mapping semantics',function()
 local original=record({keyboard});local fingerprint=N.fingerprint(original)
 assert(fingerprint==N.fingerprint(replace_word(original,12,0x111100a1)))
 for _,at in ipairs({8,12,16,20,24})do
  local changed=replace_word(original,at,word(original,at)+1)
  assert(N.fingerprint(changed)~=fingerprint,'semantic field ignored at '..at)
 end
 assert(N.fingerprint(record({keyboard,mouse}))~=fingerprint)
end)
test('empty keyboard binding appends Press and preserves other devices and tail',function()
 local original=record({mouse,pad});local after,previous=N.replace_keyboard(original,165)
 assert(previous==-1 and word(after,4)==3)
 assert(after:sub(9,48)==original:sub(9,48))
 assert(after:sub(49,68)==mapping(67,165,0,0,0))
 assert(after:sub(69)==original:sub(69)and #after==328)
 local empty=N.replace_keyboard(record({}),165)
 assert(word(empty,4)==1 and empty:sub(9,28)==mapping(67,165,0,0,0))
end)
test('full record and keyboard chords refuse without modifying bytes',function()
 local mappings={};for i=1,16 do mappings[i]=mouse end
 local full=record(mappings);local edited,why=N.replace_keyboard(full,165)
 assert(not edited and why:find('no free',1,true))
 assert(not N.replace_keyboard(record({keyboard,keyboard}),165))
 assert(not N.replace_keyboard(record({mapping(67,161,0,1,0)}),165))
 assert(not N.replace_keyboard(record({mapping(3+8*16,161,0,0,0)}),165))
end)
test('successful bind writes native action and persists stable binding id',function()
 local f=fixture();local baseline=N.fingerprint(f.bytes);assert(f.service.bind(f.record,116))
 assert(f.writes==1 and f.saves==1 and f.acks==1)
 assert(f.saved[key(f.record.id)]=='116 165 161 '..tostring(baseline))
 assert(word(f.bytes,32)==0xabcd00a5)
 assert(f.left==N.fingerprint(f.bytes))
end)
test('unsupported key codec refuses before any native or store write',function()
 local f=fixture();local original=f.bytes;local ok,why=f.service.bind(f.record,999)
 assert(not ok and why:find('Unsupported',1,true))
 assert(f.bytes==original and f.writes==0 and f.saves==0 and f.acks==0)
end)
test('failed persistence restores complete native record and keeps saved state',function()
 local f=fixture();local original=f.bytes;f.fail_save=true
 local ok,why=f.service.bind(f.record,116)
 assert(not ok and why:find('disk full',1,true))
 assert(f.bytes==original and f.writes==2 and f.saves==1 and f.acks==0)
 assert(next(f.saved)==nil)
end)
test('failed native write never commits persistence',function()
 local f=fixture();local original=f.bytes;f.fail_write=true
 assert(not f.service.bind(f.record,116))
 assert(f.bytes==original and f.writes==1 and f.saves==0 and f.acks==0)
end)
test('malformed persisted overrides never write a native mapping',function()
 for _,stored in ipairs({'garbage','116 999999 161','116 166 161','116 165 -3','116 165 161 extra'})do
  local f=fixture({saved={[key('firstperson.toggle')]=stored}});local original=f.bytes
  f.service.poll(f.host,{f.record})
  assert(f.bytes==original and f.writes==0 and f.saves==0 and f.acks==0,stored)
 end
end)
test('startup override applies only while the prior native keyboard key remains',function()
 local saved={[key('firstperson.toggle')]='116 165 161'}
 local f=fixture({saved=saved});local before=f.bytes
 f.service.poll(f.host,{f.record})
 assert(f.bytes==N.replace_keyboard(before,165)and f.writes==1 and f.acks==1 and f.saves==0)
 f.service.poll(f.host,{f.record});assert(f.writes==1,'unchanged override written again')
 local changed=N.replace_keyboard(before,166)
 local g=fixture({saved=saved,bytes=changed});g.service.poll(g.host,{g.record})
 assert(g.bytes==changed and g.writes==0 and g.saves==1 and next(g.saved)==nil)
end)
test('repeated MCM rebinds preserve the original game baseline across restart',function()
 local f=fixture();local baseline=f.bytes
 assert(f.service.bind(f.record,116));assert(f.service.bind(f.record,117))
 local restarted=fixture({saved=f.saved,bytes=baseline})
 restarted.service.poll(restarted.host,{restarted.record})
 assert(word(restarted.bytes,32)%65536==166,'latest override lost after restarting from original native baseline')
 assert(restarted.saved[key(restarted.record.id)]=='117 166 161 '..tostring(N.fingerprint(baseline)))
end)
test('startup override retires when the prior key has different native semantics',function()
 local f=fixture();local baseline=f.bytes;assert(f.service.bind(f.record,116))
 local changed=replace_word(baseline,36,0)
 local restarted=fixture({saved=f.saved,bytes=changed});restarted.service.poll(restarted.host,{restarted.record})
 assert(restarted.bytes==changed and restarted.writes==0 and restarted.saves==1 and next(restarted.saved)==nil)
end)
test('a native-page edit wins even when it restores the old keyboard key',function()
 local f=fixture();assert(f.service.bind(f.record,116))
 f.page=true;f.service.poll(f.host,{f.record})
 f.bytes=N.replace_keyboard(f.bytes,161);f.page=false
 f.service.poll(f.host,{f.record})
 assert(word(f.bytes,32)%65536==161 and f.writes==1 and next(f.saved)==nil)
end)
test('native-page exit remains authoritative while MBM refresh is pending',function()
 local f=fixture();assert(f.service.bind(f.record,116))
 f.page=true;f.service.poll(f.host,{f.record})
 f.bytes=N.replace_keyboard(f.bytes,161);f.page=false;f.blocked=true
 f.service.poll(f.host,{f.record})
 f.blocked=false;f.service.poll(f.host,{f.record})
 assert(word(f.bytes,32)%65536==161,'pending refresh discarded native-page authority')
 assert(f.writes==1 and next(f.saved)==nil)
end)
test('unsupported provider, stale snapshot and active native page stay read-only',function()
 local f=fixture();local original=f.bytes
 f.service.attach({supported=false});assert(not f.service.bind(f.record,116))
 f.service.poll({supported=false},{f.record})
 f.service.attach(f.host);f.blocked=true;assert(not f.service.bind(f.record,116))
 f.blocked=false;f.page=true;assert(not f.service.bind(f.record,116))
 assert(f.bytes==original and f.writes==0 and f.saves==0 and f.acks==0)
 f.service.release();assert(not f.service.available(f.record))
end)
test('Windows backend resolves current-vector records and refuses stale ownership',function()
 local f=windows_fixture();f.state.buckets[f.record.code]=0x40000000
 local token=assert(f.backend.snapshot(f.record));assert(token.bucket==f.bucket)
 local edited=assert(N.replace_keyboard(token.bytes,165));f.owner=f.owner+0x1000
 assert(not f.backend.write(token,edited)and #f.writes==0)
 f=windows_fixture();f.map_count=255;assert(not f.backend.snapshot(f.record))
 f=windows_fixture();f.state.assignments.actions[f.record.code].left=0;assert(not f.backend.snapshot(f.record))
end)
test('Windows backend acknowledges verified writes and rolls back failed counts',function()
 local f=windows_fixture();local token=assert(f.backend.snapshot(f.record));local edited=N.replace_keyboard(token.bytes,165)
 assert(f.backend.write(token,edited));assert(f.bytes==edited and #f.writes==2)
 assert(f.backend.acknowledge(token)and f.state.assignments.dirty)
 assert(f.state.assignments.actions[f.record.code].left==N.fingerprint(edited))
 f=windows_fixture();local original=f.bytes;token=assert(f.backend.snapshot(f.record));edited=N.replace_keyboard(token.bytes,165)
 f.fail_count=true;assert(not f.backend.write(token,edited))
 assert(f.bytes==original,'payload was left modified after count failure')
 assert(not f.state.assignments.dirty)
end)
test('Windows backend rechecks owner before committing a mapping count',function()
 local f=windows_fixture();local token=assert(f.backend.snapshot(f.record));local edited=N.replace_keyboard(token.bytes,165)
 f.change_owner_after_payload=true;assert(not f.backend.write(token,edited))
 assert(#f.writes==1,'count written after native ownership changed')
 assert(not f.state.assignments.dirty)
end)
print('Native binding transaction contracts passed: '..count)
