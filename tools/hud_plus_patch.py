"""Prepare a local HUD+ 0.2.2 owner-API patch; never install or publish it.

Only the exact supplied archive hash is accepted. All original files and resource
metadata remain intact, except the product Lua resource and its size/offsets.
The patched third-party package stays under dist and is not a public MCM asset.
"""
from __future__ import annotations
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import struct
import zipfile

from hud_plus_archive import first_language, replace, resources
from runtime_guard import require_physical_runtime

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = "9ba626afa44a3aa3.patch_0"
EXPECTED = "5da7897d174f5b39337df3195fe3a70d8c48d42f47903fbb83c8ec2560bf2b99"
PRODUCT = 0x56E46A6DC1DF0A13
STRINGS = 0x94A17A3A1257FC23
LUA_DLL = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\bin\lua51.dll")
MARKER = "-- DBF-MCM local owner bridge v2"
SCHEMA = "2d125916"


def quoted(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r") + '"'


def bridge_source(labels: dict[int, str]) -> str:
    dictionary = ",".join(f"[{key}]={quoted(value)}" for key, value in sorted(labels.items()))
    return MARKER + "\n" + r"""
    local bridge_labels={__LABELS__}
    local bridge={api=1,name='HD2 HUD+',version='0.2.2',generation={},schema_version=1,source_archive_sha256='__SOURCE_HASH__',expected_schema_fingerprint='__SCHEMA__'}
    local function bridge_copy(values)local result={};for key,value in pairs(values)do result[key]=value end;return result end
    local bridge_options=worker.options
    local bridge_order,bridge_kinds=bridge_options.order,bridge_options.kinds
    local function bridge_tag(value)
      if value==nil then return ''elseif type(value)=='boolean'then return 'b:'..tostring(value)
      elseif type(value)=='number'then return 'n:'..string.format('%.14g',value)
      elseif type(value)=='string'then return 's:'..value end
      return 'invalid'
    end
    local bridge_lines={}
    for _,id in ipairs(bridge_order)do
      local entry=bridge_kinds[id];local range,choices,option=entry.range,entry.choices,entry.option or {}
      local raw_choices={};for _,value in ipairs(choices or {})do raw_choices[#raw_choices+1]=bridge_tag(value)end
      bridge_lines[#bridge_lines+1]=table.concat({id,range and 'slider' or (choices and 'choice' or 'toggle'),bridge_tag(entry.default),bridge_tag(range and range[1]),bridge_tag(range and range[2]),bridge_tag(option.step),table.concat(raw_choices,'|')},'\t')
    end
    local bridge_canonical=table.concat(bridge_lines,'\n')..'\n';local bridge_a,bridge_b=1,0
    for index=1,#bridge_canonical do bridge_a=(bridge_a+bridge_canonical:byte(index))%65521;bridge_b=(bridge_b+bridge_a)%65521 end
    bridge.schema_fingerprint=string.format('%08x',bridge_b*65536+bridge_a)
    bridge.source_pin=bridge_copy(baked.pin or {})
    function bridge.schema()
      return {api=bridge.api,version=bridge.version,schema_version=bridge.schema_version,source_archive_sha256=bridge.source_archive_sha256,schema_fingerprint=bridge.schema_fingerprint,expected_schema_fingerprint=bridge.expected_schema_fingerprint,option_count=#bridge_order,source_pin=bridge_copy(bridge.source_pin)}
    end
    function bridge.alive()
      return type(bridge.current)=='function' and bridge.current()==true
        and Core.mcm_bridge==bridge and BootState.installed==true and BootState.result==true and BootState.armed==true
        and type(BootState.hook)=='table' and BootState.hook.driver==BootState and not worker.failed
        and worker.options==bridge_options and bridge_options.order==bridge_order and bridge_options.kinds==bridge_kinds
        and #bridge_order==41 and bridge.schema_fingerprint==bridge.expected_schema_fingerprint
    end
    function bridge.native_menu(generation)
      if (generation==nil or generation==bridge.generation) and bridge.alive() and not worker.resolving then return worker.menu end
    end
    local function bridge_label(value)
      if type(value)=='number'then return bridge_labels[value]end
      if value=='off'then return 'Off'elseif value=='on'then return 'On'end
      return type(value)=='string' and value or nil
    end
    function bridge.entries()
      local result={}
      for _,entry in ipairs(Options.entries(baked.screens))do
        local option=entry.option or {};local choices
        if entry.choices then choices={};for i,value in ipairs(entry.choices)do choices[i]=bridge_label(value) or ('Value '..i)end end
        local kind=entry.range and 'slider' or (choices and 'choice' or 'toggle')
        local step=option.step
        if kind=='slider' and not step then
          step=entry.range[2]-entry.range[1]<=10 and .01 or 1
          step=math.min(step,entry.range[2]-entry.range[1])
        end
        result[#result+1]={id=entry.id,kind=kind,label=bridge_label(option.title) or entry.id,
          description=bridge_label(option.description) or '',category=bridge_label(option.group or option.heading or entry.category) or 'Advanced placement',
          default=entry.default,choices=choices,min=entry.range and entry.range[1],max=entry.range and entry.range[2],step=step}
      end
      return result
    end
    function bridge.snapshot(generation)
      if generation~=bridge.generation or not bridge.alive()then return nil,'HUD+ bridge was retired'end
      return bridge_copy(worker.options.values)
    end
    function bridge.apply(changes,generation)
      if generation~=bridge.generation or not bridge.alive()then return false,'HUD+ bridge was retired'end
      if type(changes)~='table'then return false,'HUD+ changes must be a table'end
      if bridge.busy then return false,'HUD+ settings are already being saved'end
      if worker.resolving then return false,'HUD+ is still initializing; try again once its native menu is available'end
      local options=worker.options
      if (worker.menu and worker.menu.view) or options:dirty()then return false,'Close or apply the native HUD+ settings before editing MCM'end
      local previous={pending=options.pending,base=options.base,begun=options.begun,extra=options.extra}
      local function restore()options.pending,options.base,options.begun,options.extra=previous.pending,previous.base,previous.begun,previous.extra end
      options:begin()
      for id,value in pairs(changes)do
        local okay,why=options:edit(id,value)
        if not okay then restore();return false,why or 'HUD+ value was rejected'end
      end
      bridge.busy=true
      local called,okay,why=pcall(worker.apply_options,worker)
      bridge.busy=nil
      if not called or not okay then restore();return false,tostring(called and why or okay)end
      -- No native editor owns this temporary clean draft; keep it closed.
      options.pending,options.base,options.begun=nil,nil,nil
      return true,bridge_copy(options.values)
    end
    Core.mcm_bridge=bridge
""".replace("__LABELS__", dictionary).replace("__SOURCE_HASH__", EXPECTED).replace("__SCHEMA__", SCHEMA)


EXPORT = """
-- DBF-MCM local owner bridge publication; original HUD+ startup remains its owner.
local __mcm_owner=__module_registry["Main"]
local __mcm_bridge=type(__mcm_owner)=='table' and __mcm_owner.mcm_bridge or nil
if __boot_state.result==true and type(__mcm_bridge)=='table' then
  __mcm_bridge.current=function()return rawget(_G,'HD2HUDPlusMCMBridge')==__mcm_bridge end
  rawset(_G,'HD2HUDPlusMCMBridge',__mcm_bridge)
end
return {installed=__boot_state.result==true,mcm_bridge=__mcm_bridge}
"""


def compile_lua(source: bytes, dll_path: Path) -> None:
    dll = ctypes.CDLL(str(dll_path))
    state_type = ctypes.c_void_p
    dll.luaL_newstate.restype = state_type
    dll.luaL_loadbuffer.argtypes = [state_type, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    dll.lua_tolstring.argtypes = [state_type, ctypes.c_int, ctypes.c_void_p]
    dll.lua_tolstring.restype = ctypes.c_char_p
    dll.lua_close.argtypes = [state_type]
    state = dll.luaL_newstate()
    try:
        if dll.luaL_loadbuffer(state, source, len(source), b"@hud_plus_mcm_review"):
            raise RuntimeError(dll.lua_tolstring(state, -1, None).decode(errors="replace"))
    finally:
        dll.lua_close(state)


def prepare(package: Path, output: Path, dll_path: Path) -> dict:
    data = (package / ARCHIVE).read_bytes()
    original_hash = hashlib.sha256(data).hexdigest()
    if original_hash != EXPECTED:
        raise ValueError("The input is not the verified HUD+ 0.2.2 archive; no patch was produced")
    rows = resources(data)
    product = next(row for row in rows if row.name == PRODUCT)
    strings = next(row for row in rows if row.name == STRINGS)
    envelope = data[product.offset:product.offset + product.size]
    length, version = struct.unpack_from("<II", envelope)
    if version != 2 or length != len(envelope) - 8:
        raise ValueError("Unsupported HUD+ Lua envelope")
    source = envelope[8:].decode("utf-8")
    if MARKER in source:
        raise ValueError("The HUD+ owner bridge was already patched")
    anchor = "    worker:attach_menu()\n"
    ending = "return { installed = __boot_state.result == true }\n"
    if source.count(anchor) != 1 or source.count(ending) != 1 or not source.endswith(ending):
        raise ValueError("HUD+ worker initialization/export anchors changed")
    labels = first_language(data[strings.offset:strings.offset + strings.size])
    if labels.get(1207430374) != "HUD+":
        raise ValueError("Expected English HUD+ localization was not found")
    patched = source.replace(anchor, bridge_source(labels) + anchor, 1)
    patched = patched[:-len(ending)] + EXPORT
    encoded = patched.encode("utf-8")
    compile_lua(encoded, dll_path)  # Compilation only: the full HUD+ product is never executed here.
    patched_archive = replace(data, PRODUCT, struct.pack("<II", len(encoded), 2) + encoded)
    files = sorted(path for path in package.iterdir() if path.is_file())
    if not (package / "manifest.json").is_file():
        raise ValueError("The original package manifest is missing")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise ValueError("Output already exists; choose a new review path")
    note = "Local HUD+ 0.2.2 MCM owner-bridge review patch r3.\nNot installed or live verified.\nOriginal HUD+ manifest, GUID, assets, native owner and settings file are preserved.\nWith the game closed, back up the existing Arsenal HUD+ package and deployed archive, then replace/update that same HUD+ package and deploy through Arsenal. Do not enable two copies.\nOnly the product Lua resource is modified. The original WWISE startup wrapper is unchanged. If another mod wins that wrapper, MCM must perform its guarded exact-resource load.\nA fresh normal game launch is required: already loaded Lua modules are cached and changing files cannot replace their running owner. Do not clear package.loaded or re-execute an installed HUD+ instance.\nThe exact product module returns mcm_bridge and publishes HD2HUDPlusMCMBridge in its own global namespace.\nThis third-party package is a local review artifact and must not be uploaded as an MCM release asset.\n"
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            archive.writestr(path.name, patched_archive if path.name == ARCHIVE else path.read_bytes())
        archive.writestr("MCM-BRIDGE-README.txt", note)
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise ValueError("Review ZIP integrity failed")
        for path in files:
            expected = patched_archive if path.name == ARCHIVE else path.read_bytes()
            if archive.read(path.name) != expected:
                raise ValueError("Review ZIP file preservation failed")
    report = {"hud_plus_version": "0.2.2", "original_archive_sha256": original_hash,
              "patched_archive_sha256": hashlib.sha256(patched_archive).hexdigest(),
              "review_zip_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
              "resource_count": len(rows), "changed_resource": f"{PRODUCT:016x}",
              "unchanged_resources": len(rows) - 1, "localization_count": len(labels),
              "bridge_api": 1, "bridge_schema_version": 1, "expected_schema_fingerprint": SCHEMA,
              "native_menu_exposed": True, "cached_resource_export": "mcm_bridge", "original_wrapper_unchanged": True,
              "syntax_verified": True, "deployed": False, "live_verified": False,
              "third_party_review_only": True}
    output.with_suffix(".verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main() -> None:
    require_physical_runtime()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--lua-dll", type=Path, default=LUA_DLL)
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to((ROOT / "dist").resolve()) or output.suffix.lower() != ".zip":
        parser.error("Use an explicitly named .zip review output inside this repository's dist directory")
    report = prepare(args.package_dir.resolve(), output, args.lua_dll)
    print(json.dumps(report, indent=2))
    print(output)


if __name__ == "__main__":
    main()
