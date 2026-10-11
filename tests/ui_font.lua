-- Exact-build, read-only loaded font discovery; no native calls.
local Font=dofile('src/ui/font.lua')
local base,owner=0x180000000,0x270010000
local function u32(n)local b={};for i=1,4 do b[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(b)end
local function u64(lo,hi)return u32(lo)..u32(hi or 0)end
local image={
 [base+0x3c]=u32(0x110),[base+0x110]=u32(0x4550),[base+0x118]=u32(0x6AB3B43F),
 [base+0x160]=u32(0x4744000),[base+0x168]=u32(0xECDA6F),
 [base+0x3772268]=u64(0xfedcba98,0x76543210),[base+0x3772EE8]=u64(0x13572468,0xabcdef01),
 [base+0x37C5478]=u64(owner%4294967296,math.floor(owner/4294967296)),[owner+24]=u64(0x55667788,0x11223344),
}
local reads,frame,availability={},1,true
local memory={address=function(value)return value end,read=function(address,size)
 reads[#reads+1]=address;local bytes=image[address];assert(bytes==nil or #bytes==size,'Unexpected read size');return bytes
end}
local sr={IdString64={from_hex=function(value)return {hex=value,frame=frame}end},Application={can_get=function(kind,value)
 assert(value.frame==frame,'Native ID retained across frames');return availability~=kind and availability~=false
end}}
local source=Font.new(memory,base)
local function expected()
 local d=source.resolve(sr);assert(d and d.font=='76543210fedcba98' and d.atlas=='abcdef0113572468' and d.material=='1122334455667788','64-bit descriptor bytes changed')
 for _,value in pairs(d)do assert(type(value)=='string','Native ID escaped resolver')end
end
expected();frame=2;expected()
-- Production adapter supplies the literal module name; address() only accepts
-- a loaded pointer. This is different from a mocked numeric base.
local module_queries,address_queries=0,0
local named_memory={read=memory.read,module=function(name)
 assert(name=='game.dll','Unexpected module lookup');module_queries=module_queries+1;return {base=base}
end,address=function(value)
 assert(type(value)=='table' and value.base,'Module name treated as pointer');address_queries=address_queries+1;return value.base
end}
assert(Font.new(named_memory,'game.dll').resolve(sr),'Production module-name path used stock fallback')
assert(module_queries==1 and address_queries==1,'Module name did not resolve to one owned pointer')
named_memory.module=function()return nil end
assert(Font.new(named_memory,'game.dll').resolve(sr)==nil and address_queries==1,'Missing module passed into address()')
assert(Font.new(memory,'game.dll').resolve(sr)==nil,'Module name accepted without module resolver')
local function rejects(address,bytes,reason)
 local prior=image[address];image[address]=bytes;reads={};assert(source.resolve(sr)==nil,reason);image[address]=prior
end
for _,address in ipairs({base+0x110,base+0x118,base+0x160,base+0x168})do
 rejects(address,u32(0),'Mismatched executable accepted')
 for _,at in ipairs(reads)do assert(at<base+0x10000,'Unsupported build read font globals')end
end
for _,n in ipairs({0,0x3f,0x1001})do rejects(base+0x3c,u32(n),'Invalid PE offset accepted')end
for _,address in ipairs({base+0x3772268,base+0x3772EE8,owner+24})do
 rejects(address,u64(0),'Zero resource accepted');rejects(address,nil,'Missing resource accepted')
end
for _,bytes in ipairs({u64(0),u64(1),u64(0,0x8000),u64(0xffffffff,0x7fff)})do rejects(base+0x37C5478,bytes,'Unsafe owner pointer accepted')end
for _,kind in ipairs({'font','texture','material'})do availability=kind;assert(source.resolve(sr)==nil,'Unloaded '..kind..' accepted')end
availability=true
assert(Font.new(nil,base).resolve(sr)==nil and source.resolve({})==nil,'Missing API did not fall back')
for _,bad in ipairs({0,0xffff,0x800000000000,base+.5,math.huge})do assert(Font.new(memory,bad).resolve(sr)==nil,'Invalid module base accepted')end
local read=memory.read;local conversions=0
memory.read=function(address,size)assert(type(address)=='table','Address adapter skipped');return read(address.address,size)end
local converted=Font.new(memory,base,function(address)conversions=conversions+1;return {address=address}end)
assert(converted.resolve(sr) and conversions==9,'Not every module/owner read converted')
memory.read=function()error('Unavailable read')end
assert(source.resolve(sr)==nil,'Read exception escaped resolver')
print('PASS loaded game UI font: production module lookup, exact build gate, bounded pointers, precise HEX descriptors, fresh IDs and read-only fallback')
