-- HD2-Addon: mods/dbf_mcm/startup
-- Startup entry; the menu implementation is shared with the optional MDL adapter.
if rawget(_G,'DBFMCM') then return end
local ffi=require('ffi')
pcall(ffi.cdef,'int CreateDirectoryA(const char*, void*);')
local win=ffi.load('kernel32')
local base=assert(os.getenv('LOCALAPPDATA'),'Local AppData unavailable')..'/DBF'
win.CreateDirectoryA(base,nil);base=base..'/MCM';win.CreateDirectoryA(base,nil)
local settings_root=assert(os.getenv('LOCALAPPDATA'))
for _,part in ipairs({'MDL','Helldivers2','Mods','dbf_mcm','settings'})do
 settings_root=settings_root..'/'..part;win.CreateDirectoryA(settings_root,nil)
end
local native_name='__NATIVE_NAME__'
local hex='__NATIVE_HEX__'
local payload=hex:gsub('%x%x',function(pair)return string.char(tonumber(pair,16))end)
local path=base..'/'..native_name
local existing=io.open(path,'rb');local matches=false
if existing then matches=existing:read('*a')==payload;existing:close()end
if not matches then local f=assert(io.open(path,'wb'));assert(f:write(payload));assert(f:close())end
local manifest=assert(io.open(base..'/library.txt','wb'));assert(manifest:write(native_name));assert(manifest:close())
local descriptor=(function()
-- __MODULE__
end)()
local cleanup,globals={},{}
local ctx={api=2,dir=base,diagnostic_log_path=base..'/MCM-startup.log'}
function ctx.log(message)local f=io.open(base..'/MCM-startup.log','a');if f then f:write(tostring(message),'\n');f:close()end end
function ctx.global(name,value)globals[name]={previous=rawget(_G,name),owned=value};rawset(_G,name,value);return value end
function ctx.on_cleanup(fn)cleanup[#cleanup+1]=fn end
local original_update=assert(rawget(_G,'update'),'Game update callback unavailable')
local original_shutdown=rawget(_G,'shutdown');local retired=false
local function close()
 if retired then return end;retired=true
 for i=#cleanup,1,-1 do local ok,err=pcall(cleanup[i]);if not ok then ctx.log(err)end end
 for name,record in pairs(globals)do if rawget(_G,name)==record.owned then rawset(_G,name,record.previous)end end
end
local ok,err=pcall(descriptor.on_enable,ctx)
if not ok then close();ctx.log('Startup failed: '..tostring(err));return end
local wrapper
wrapper=function(dt,...)
 local result=original_update(dt,...)
 if not retired then local worked,why=pcall(descriptor.on_update,ctx,dt);if not worked then ctx.log(why);close()end end
 return result
end
rawset(_G,'update',wrapper)
rawset(_G,'shutdown',function(...)
 close();if rawget(_G,'update')==wrapper then rawset(_G,'update',original_update)end
 if type(original_shutdown)=='function' then return original_shutdown(...)end
end)
ctx.log('Shared Loader startup enabled; MDL is optional and must not run a second MCM instance.')
return descriptor
