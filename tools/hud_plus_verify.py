"""Exercise the supplied pure Options owner with fake in-memory I/O, never its HUD runtime."""
from __future__ import annotations
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import re
import struct
import zlib

from hud_plus_archive import first_language, resources
from hud_plus_patch import ARCHIVE, EXPECTED, LUA_DLL, PRODUCT, ROOT, STRINGS, bridge_source, quoted
from runtime_guard import require_physical_runtime


def literal_only(value: str) -> None:
    masked = re.sub(r'"(?:\\.|[^"\\])*"', '""', value)
    masked = re.sub(r"'(?:\\.|[^'\\])*'", "''", masked)
    masked = re.sub(r"(?<![\w])[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", "0", masked)
    if re.search(r"[^\w\s{}\[\],=.'\"]", masked):
        raise ValueError("The baked data contains executable syntax")
    for token in re.finditer(r"[A-Za-z_]\w*", masked):
        if token.group() not in {"true", "false", "nil"} and not masked[token.end():].lstrip().startswith("="):
            raise ValueError("The baked data contains a nonliteral value")


def verify(package: Path, dll_path: Path, metadata_output: Path | None = None, runtime: bool = False) -> dict:
    data = (package / ARCHIVE).read_bytes()
    if hashlib.sha256(data).hexdigest() != EXPECTED:
        raise ValueError("Unknown HUD+ source archive")
    rows = resources(data)
    product = next(row for row in rows if row.name == PRODUCT)
    strings = next(row for row in rows if row.name == STRINGS)
    body = data[product.offset + 8:product.offset + product.size].decode("utf-8")
    declaration = next(line for line in body.splitlines() if line.startswith("local GameBaked = "))
    literal_only(declaration.removeprefix("local GameBaked = "))
    start = body.index("local Options = (function()")
    end = body.index("\nlocal __contract_ok_1", start)
    options = body[start:end]
    boot_start=body.index('local BootState = (function()')
    boot_end=body.index('\nlocal __contract_ok_1',boot_start)
    boot=body[boot_start:boot_end].replace('local BootState = (function()','local RecoveredBootState = (function()',1)
    labels = first_language(data[strings.offset:strings.offset + strings.size])
    script = """
local io={open=function()error('offline file access blocked')end}
local os={getenv=function()error('offline environment path access blocked')end}
""" + declaration + "\n" + options + "\n" + """
local baked=GameBaked
local text,save_count,configure_count='',0,0
local fail_save=false
local BootState={armed=true,installed=true,result=true,hook={}};BootState.hook.driver=BootState;local Core={}
local worker={baked=baked}
worker.options=Options.new(baked.screens,nil,function()return text end,function(value)
  if fail_save then return nil,'synthetic disk failure'end
  text=value;save_count=save_count+1;return true
end)
worker.options:poll()
function worker:apply_options()
  local values,why=self.options:apply();if not values then return nil,why end
  configure_count=configure_count+1;return true
end
""" + bridge_source(labels) + "\n" + r"""
bridge.current=function()return true end
worker.menu={native_owner_marker=true}
assert(bridge.native_menu()==worker.menu and bridge.native_menu(bridge.generation)==worker.menu and bridge.native_menu({})==nil,'Cold owner menu identity/token guard failed')
local declared=bridge.schema();assert(declared.source_archive_sha256=='__SOURCE_HASH__' and declared.schema_fingerprint=='2d125916' and declared.option_count==41 and declared.schema_version==1,'Cold owner source/schema metadata failed')
declared.source_pin.exe='changed';assert(bridge.schema().source_pin.exe~=declared.source_pin.exe,'Schema metadata was mutable')
worker.resolving=true;assert(bridge.native_menu()==nil and bridge.apply({},bridge.generation)==false,'Initializing owner accepted native writes');worker.resolving=nil
BootState.result=false;assert(not bridge.alive());BootState.result=true
local original_driver=BootState.hook.driver;BootState.hook.driver={};assert(not bridge.alive() and bridge.native_menu()==nil);BootState.hook.driver=original_driver
local function json_quote(value)
 return '"'..value:gsub('[%z\1-\31\\"]',function(char)
  if char=='"'then return '\\"'elseif char=='\\'then return '\\\\'end
  return string.format('\\u%04x',char:byte())
 end)..'"'
end
local function json(value)
 local kind=type(value)
 if kind=='nil'then return 'null'elseif kind=='boolean'then return tostring(value)
 elseif kind=='number'then return string.format('%.14g',value)
 elseif kind=='string'then return json_quote(value)
 elseif kind=='table'then
  local parts={};if #value>0 then for i=1,#value do parts[#parts+1]=json(value[i])end;return '['..table.concat(parts,',')..']'end
  local keys={};for key in pairs(value)do keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys)do parts[#parts+1]=json_quote(key)..':'..json(value[key])end;return '{'..table.concat(parts,',')..'}'
 end
 error('Unsupported metadata value')
end
local metadata={schema=1,version='0.2.2',source_archive_sha256='__SOURCE_HASH__',pin=baked.pin,entries=bridge.entries(),owner_schema={}}
for _,id in ipairs(worker.options.order)do local entry=worker.options.kinds[id]
 metadata.owner_schema[#metadata.owner_schema+1]={id=id,default=entry.default,min=entry.range and entry.range[1],max=entry.range and entry.range[2],choices=entry.choices,step=entry.option and entry.option.step}
end
HUD_PLUS_METADATA_JSON=json(metadata)
local Framework=dofile(__CORE__);local Integration=dofile(__INTEGRATION__)
local api=Framework.new();local integration=Integration.new(api)
local registered,registration_error=integration.poll(bridge);assert(registered,registration_error)
local handle=api.mods.hud_plus.handle;local categories=#api.mods.hud_plus.pages
local entries=bridge.entries();local controls=0;for _ in pairs(api.mods.hud_plus.controls)do controls=controls+1 end
assert(controls==#entries and controls>20,'Incomplete HUD+ control import')
local trajectory=Integration.control_id('hud.trajectory')
assert(handle.get(trajectory)==2,'Original zero-based default was not converted')
text='hud.weapon3d.opacity=0.6\naddon.extra=17\n'
assert(handle.set(trajectory,3),'Actual owner apply failed')
assert(worker.options.values['hud.trajectory']==2 and worker.options.values['hud.weapon3d.opacity']==.6)
assert(handle.get(Integration.control_id('hud.weapon3d.opacity'))==.6,'Concurrent setting was overwritten')
assert(text:find('addon.extra=17',1,true) and save_count==1 and configure_count==1)
assert(worker.options.pending==nil,'Temporary clean draft was left open')
worker.options:begin();assert(worker.options:edit('hud.world3d.size',1.1))
local toggled=Integration.control_id('hud.stratagem3d')
local okay,why=handle.set(toggled,false)
assert(not okay and why:find('native HUD+',1,true) and worker.options.pending['hud.world3d.size']==1.1 and save_count==1)
worker.options:cancel();worker.menu={view={}}
okay=handle.set(toggled,false);assert(not okay and save_count==1)
worker.menu=nil;fail_save=true;local before=text
okay,why=handle.set(toggled,false)
assert(not okay and why=='synthetic disk failure' and text==before and configure_count==1 and handle.get(toggled)==true)
assert(worker.options.pending==nil,'Failed save damaged previous draft ownership')
fail_save=false;assert(handle.set(toggled,false));assert(worker.options.values['hud.stratagem3d']==false and save_count==2 and configure_count==2)
bridge.current=function()return false end
assert(not integration.poll(bridge) and not api.mods.hud_plus,'Retired owner remained registered')
HUD_PLUS_VERIFY_JSON=string.format('{"actual_owner_options":true,"controls":%d,"categories":%d,"owner_saves":%d,"native_apply_surrogate_calls":%d,"cold_patch_native_menu":true,"cold_patch_schema_metadata":true,"original_driver_guard":true,"initializing_write_refusal":true,"concurrent_merge":true,"unknown_lines_preserved":true,"draft_refusal":true,"failed_save_isolation":true,"game_runtime_executed":false}',controls,categories,save_count,configure_count)
""".replace("__SOURCE_HASH__", EXPECTED).replace("__CORE__", quoted(str(ROOT / "src" / "core.lua"))).replace("__INTEGRATION__", quoted(str(ROOT / "src" / "integrations" / "hud_plus.lua")))
    if runtime:
        script += r"""
local virtual={update=function()end,shutdown=function()end}
local stingray=nil
local frame_update={get=function()return virtual.update end,set=function(fn)virtual.update=fn end}
local frame_shutdown={get=function()return virtual.shutdown end,set=function(fn)virtual.shutdown=fn end}
""" + boot + r"""
local Runtime=dofile(__RUNTIME__)
metadata.fingerprint='2d125916'
for index,entry in ipairs(metadata.entries)do local native=metadata.owner_schema[index];entry.owner_step=native.step;entry.raw_choices=native.choices end
local updates,closes=0,0
function worker:update()updates=updates+1 end
function worker:close()closes=closes+1 end
worker.menu={native_owner_marker=true}
assert(RecoveredBootState.install(worker),'Actual BootState installer failed')
local found,driver,hook=Runtime.find(virtual.update,metadata)
assert(found==worker and driver==RecoveredBootState and hook==RecoveredBootState.hook,'Exact named hook did not recover actual owner')
assert(updates==0 and closes==0,'Discovery executed owner frame/cleanup')
local provider=Runtime.new('',function()end,{globals=virtual,metadata=metadata})
local live,reason=provider.poll();assert(live,reason)
assert(live.native_menu()==worker.menu and live.snapshot(live.generation),'Live owner API is incomplete')
local runtime_api=Framework.new();local runtime_integration=Integration.new(runtime_api)
assert(runtime_integration.poll(live));local runtime_handle=runtime_api.mods.hud_plus.handle
local fractional
for _,entry in ipairs(metadata.entries)do
 if entry.kind=='slider' and entry.owner_step==nil and entry.default%1==0 and entry.min<=.75 and entry.max>=.75 and entry.max-entry.min<=10 then fractional=entry.id;break end
end
assert(fractional,'No implicit fractional range fixture found in actual metadata')
assert(runtime_handle.set(Integration.control_id(fractional),.75))
assert(worker.options.values[fractional]==.75,'Implicit integer-bound range discarded fractional edit')
local before=virtual.update;local previous_update=before
virtual.update=function(...)return previous_update(...)end
local original_find=Runtime.find;local wrapper_scans=0
Runtime.find=function(...)wrapper_scans=wrapper_scans+1;return original_find(...)end
local before_wrapper_save=save_count
assert(live.alive() and live.native_menu()==worker.menu and wrapper_scans==1,'Cooperative update wrapper temporarily retired the same owner')
assert(live.alive() and wrapper_scans==1 and save_count==before_wrapper_save,'Unchanged wrapper rescanned or saved owner settings')
assert(provider.poll()==live,'Other mod wrapper replaced owner generation')
assert(wrapper_scans==1,'Poll rescanned an already verified cooperative wrapper')
local wrapped_update=virtual.update
virtual.update=function()end
assert(not live.alive() and not live.alive() and wrapper_scans==2,'Dropped owner remained alive or rescanned repeatedly')
assert(provider.poll()==nil and wrapper_scans==2,'Dropped-owner inspection was repeated during poll')
virtual.update=wrapped_update;live=provider.poll();assert(live and live.alive(),'Restored update owner did not recover')
Runtime.find=original_find
local function stripped(fn)
 local values={};for index=1,64 do local name,value=debug.getupvalue(fn,index);if name==nil then break end;values[index]={value=value}end
 local result=assert(loadstring(string.dump(fn,true)));setfenv(result,getfenv(fn))
 for index,value in ipairs(values)do debug.setupvalue(result,index,value.value==fn and result or value.value)end
 return result
end
local saved_frame,saved_close=RecoveredBootState.frame,RecoveredBootState.close
RecoveredBootState.frame=stripped(saved_frame);RecoveredBootState.close=stripped(saved_close)
local stripped_root=virtual.update
for _=1,24 do local previous_update=stripped_root;stripped_root=stripped(function(...)return previous_update(...)end)end
assert(debug.getupvalue(stripped_root,1)=='' and debug.getupvalue(RecoveredBootState.frame,1)=='' and debug.getupvalue(RecoveredBootState.close,1)=='','Fixture retained names instead of stripping bytecode')
local stripped_worker,stripped_driver,stripped_hook,_,stripped_diagnostic=Runtime.find(stripped_root,metadata)
assert(stripped_worker==worker and stripped_driver==RecoveredBootState and stripped_hook==RecoveredBootState.hook and stripped_diagnostic.nodes>=25,'Stripped wrappers/callbacks hid the validated owner')
local foreign_c=math.floor;local previous_update=stripped_root
local mixed=stripped(function(value)foreign_c(value or 0);return previous_update(value)end)
local mixed_worker,_,_,_,mixed_diagnostic=Runtime.find(mixed,metadata)
assert(mixed_worker==worker and mixed_diagnostic.c_skipped>=1 and updates==0,'C builtin was followed/executed during anonymous recovery')
virtual.update=mixed;assert(live.alive() and provider.poll()==live,'Anonymous wrapper changed live owner generation')
RecoveredBootState.frame,RecoveredBootState.close=saved_frame,saved_close
local callback=virtual.update
local named_callback=function(...)return callback(...)end
local func=named_callback
local named_func=function(...)return func(...)end
local named_worker,named_driver,named_hook=Runtime.find(named_func,metadata)
assert(named_worker==worker and named_driver==RecoveredBootState and named_hook==RecoveredBootState.hook and updates==0,'Named callback/func wrapper hid owner or executed update')
virtual.update=named_func;assert(live.alive() and provider.poll()==live,'Named wrapper changed owner generation')
local loop;loop=function(...)return loop(...)end
assert(Runtime.find(loop,metadata)==nil,'Unrelated loop was treated as owner')
local deep=before
for _=1,60 do local inner=deep;deep=function(...)return inner(...)end end
assert(Runtime.find(deep,metadata)==nil,'Traversal depth limit was ignored')
local schema_entry=worker.options.kinds[worker.options.order[1]];local original_default=schema_entry.default
schema_entry.default=999;assert(Runtime.find(before,metadata)==nil,'Malformed owner schema was accepted');schema_entry.default=original_default
virtual.update=before;assert(provider.poll()==live)
local saved_text,saved_count=text,save_count;worker.options:begin();assert(worker.options:edit('hud.world3d.size',1.1))
local okay=live.apply({['hud.stratagem3d']=true},live.generation)
assert(not okay and worker.options.pending['hud.world3d.size']==1.1 and text==saved_text and save_count==saved_count,'Live bridge damaged native draft')
worker.options:cancel()
assert(live.apply({},{} )==false,'Wrong generation was accepted')
provider.release();assert(virtual.HD2HUDPlusMCMBridge==nil and not live.alive() and RecoveredBootState.armed==true and closes==0)
live=provider.poll();assert(live and live.native_menu()==worker.menu)
RecoveredBootState.close();assert(provider.poll()==nil and virtual.HD2HUDPlusMCMBridge==nil and closes==1)
assert(updates==0,'Reflection executed the game/HUD update')
HUD_PLUS_RUNTIME_VERIFY_JSON=string.format('{"actual_boot_state":true,"exact_hook_recovery":true,"controls":%d,"native_menu_identity":true,"wrapper_coexistence":true,"named_callback_func_wrappers":true,"stripped_wrappers_and_callbacks":true,"c_functions_skipped":true,"immediate_wrapper_liveness":true,"one_scan_per_wrapper":true,"dropped_owner_refusal":true,"bounded_cycles_and_depth":true,"schema_refusal":true,"fractional_implicit_slider":true,"draft_preserved":true,"retirement":true,"game_runtime_executed":false}',#metadata.entries)
""".replace('__RUNTIME__',quoted(str(ROOT / 'src' / 'integrations' / 'hud_plus_runtime.lua')))
        replacement_boot=boot.replace('local RecoveredBootState = (function()','local ReplacementBootState = (function()',1)
        script += '\n'+replacement_boot+r"""
local old_live=live;local unchanged_update=virtual.update
ReplacementBootState.adopt(RecoveredBootState.hook)
assert(ReplacementBootState.install(worker),'Actual owner adoption failed')
assert(virtual.update==unchanged_update,'Adopted owner unnecessarily changed its update hook')
local rebound=provider.poll()
assert(rebound and rebound~=old_live and not old_live.alive() and rebound.alive(),'Same-hook owner replacement stayed stale')
assert(runtime_integration.poll(rebound),'Replaced owner was not registered')
HUD_PLUS_RUNTIME_VERIFY_JSON=HUD_PLUS_RUNTIME_VERIFY_JSON:gsub('"retirement":true','"retirement":true,"same_hook_owner_replacement":true')
"""
        active_boot=boot.replace('local RecoveredBootState = (function()','local LatestBootState = (function()',1)
        script += '\n'+active_boot+r"""
LatestBootState.adopt(ReplacementBootState.hook);assert(LatestBootState.install(worker))
assert(not rebound.alive(),'Changed owner remained alive before provider poll')
local latest=provider.poll();assert(latest and latest~=rebound and latest.alive(),'Active replacement did not recover on poll')
provider.release();assert(LatestBootState.armed==true and closes==1,'MCM cleanup closed the HUD+ owner')
HUD_PLUS_RUNTIME_VERIFY_JSON=HUD_PLUS_RUNTIME_VERIFY_JSON:gsub('"retirement":true','"retirement":true,"active_owner_replacement":true')
"""
    encoded = script.encode("utf-8")
    dll = ctypes.CDLL(str(dll_path));state_type=ctypes.c_void_p
    dll.luaL_newstate.restype=state_type
    dll.luaL_openlibs.argtypes=[state_type]
    dll.luaL_loadbuffer.argtypes=[state_type,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p]
    dll.lua_pcall.argtypes=[state_type,ctypes.c_int,ctypes.c_int,ctypes.c_int]
    dll.lua_tolstring.argtypes=[state_type,ctypes.c_int,ctypes.c_void_p];dll.lua_tolstring.restype=ctypes.c_char_p
    dll.lua_getfield.argtypes=[state_type,ctypes.c_int,ctypes.c_char_p]
    dll.lua_close.argtypes=[state_type]
    state=dll.luaL_newstate()
    try:
        dll.luaL_openlibs(state)
        status=dll.luaL_loadbuffer(state,encoded,len(encoded),b"@hud_plus_owner_contract") or dll.lua_pcall(state,0,0,0)
        if status:
            raise RuntimeError(dll.lua_tolstring(state,-1,None).decode(errors="replace"))
        dll.lua_getfield(state,-10002,b"HUD_PLUS_VERIFY_JSON")
        report=json.loads(dll.lua_tolstring(state,-1,None).decode())
        if runtime:
            dll.lua_getfield(state,-10002,b'HUD_PLUS_RUNTIME_VERIFY_JSON')
            report['runtime_recovery']=json.loads(dll.lua_tolstring(state,-1,None).decode())
        if metadata_output:
            dll.lua_getfield(state,-10002,b"HUD_PLUS_METADATA_JSON")
            metadata=json.loads(dll.lua_tolstring(state,-1,None).decode())
            report.update(write_metadata(metadata,metadata_output))
            check=('local R=dofile('+quoted(str(ROOT / 'src' / 'integrations' / 'hud_plus_runtime.lua'))+');local metadata,err=R.read_metadata('+quoted(str(metadata_output.resolve()))+');assert(metadata,err)').encode()
            status=dll.luaL_loadbuffer(state,check,len(check),b'@hud_plus_metadata_contract') or dll.lua_pcall(state,0,0,0)
            if status:raise RuntimeError(dll.lua_tolstring(state,-1,None).decode(errors='replace'))
            report['metadata_parser_verified']=True
        return report
    finally:
        dll.lua_close(state)


def scalar(value) -> str:
    if value is None:return ''
    if isinstance(value,bool):return 'b:true' if value else 'b:false'
    if isinstance(value,(int,float)):return 'n:'+format(value,'.14g')
    if isinstance(value,str):return 's:'+value
    raise ValueError('Unsupported owner schema scalar')


def escaped(value: str) -> str:
    return value.replace('\\','\\\\').replace('\t','\\t').replace('\n','\\n').replace('\r','\\r').replace('|','\\p')


def write_metadata(metadata: dict, output: Path) -> dict:
    rows=[];canonical=[]
    for entry,owner in zip(metadata['entries'],metadata['owner_schema']):
        if entry['id']!=owner['id']:raise ValueError('Owner metadata order changed')
        raw_choices='|'.join(escaped(scalar(value)) for value in owner.get('choices',[]))
        canonical.append('\t'.join([owner['id'],entry['kind'],scalar(owner['default']),scalar(owner.get('min')),scalar(owner.get('max')),scalar(owner.get('step')),raw_choices]))
        rows.append('\t'.join([escaped(entry['id']),entry['kind'],escaped(scalar(owner['default'])),escaped(scalar(owner.get('min'))),escaped(scalar(owner.get('max'))),escaped(scalar(entry.get('step'))),escaped(scalar(owner.get('step'))),escaped(entry['label']),escaped(entry['description']),escaped(entry['category']),'|'.join(escaped(value) for value in entry.get('choices',[])),raw_choices]))
    fingerprint=f'{zlib.adler32((chr(10).join(canonical)+chr(10)).encode()):08x}'
    header='\t'.join(['DBF-HUD-PLUS-METADATA','1',metadata['version'],metadata['source_archive_sha256'],metadata['pin']['exe'],metadata['pin']['game'],str(len(rows)),fingerprint])
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(header+'\n'+'\n'.join(rows)+'\n',encoding='utf-8')
    return {'metadata_file':output.name,'schema_fingerprint':fingerprint,'metadata_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'source_pin_exe':metadata['pin']['exe'],'source_pin_game':metadata['pin']['game']}


def main() -> None:
    require_physical_runtime()
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package-dir",required=True,type=Path)
    parser.add_argument("--lua-dll",type=Path,default=LUA_DLL)
    parser.add_argument("--report",type=Path)
    parser.add_argument("--metadata",type=Path,help="Generate a non-executable runtime owner metadata sidecar")
    parser.add_argument("--runtime",action='store_true',help="Verify actual BootState hook recovery with a surrogate worker")
    args=parser.parse_args()
    if any(path and not path.resolve().is_relative_to((ROOT / "dist").resolve()) for path in [args.report,args.metadata]):
        parser.error("Save verification reports only inside this repository's dist directory")
    report=verify(args.package_dir.resolve(),args.lua_dll,args.metadata,args.runtime)
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps(report,indent=2))


if __name__ == "__main__":
    main()
