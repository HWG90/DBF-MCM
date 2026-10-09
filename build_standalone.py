"""Build the Shared Loader startup variant with an embedded native input library."""
from pathlib import Path
import subprocess, sys, ctypes, zipfile, json, struct
from tools.runtime_guard import require_physical_runtime
require_physical_runtime()
ROOT=Path(__file__).resolve().parent
subprocess.run([sys.executable,str(ROOT/'build.py')],check=True)
from tools.lua_archive import hash_name, write, read
name=(ROOT/'native/build/library.txt').read_text().strip()
native=(ROOT/'native/build'/name).read_bytes()
module=(ROOT/'dist/dbf_mcm/mod.lua').read_text(encoding='utf-8')
source=(ROOT/'src/startup.lua').read_text(encoding='utf-8').replace('__NATIVE_NAME__',name).replace('__NATIVE_HEX__',native.hex()).replace('-- __MODULE__',module)
entry=ROOT/'dist/dbf_mcm_startup.lua';entry.write_text(source,encoding='utf-8')
dll=ctypes.CDLL(r'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\bin\lua51.dll');dll.luaL_newstate.restype=ctypes.c_void_p;state=dll.luaL_newstate();dll.luaL_loadfile.argtypes=[ctypes.c_void_p,ctypes.c_char_p];dll.lua_close.argtypes=[ctypes.c_void_p]
try:assert dll.luaL_loadfile(state,str(entry).encode())==0,'Startup Lua compilation failed'
finally:dll.lua_close(state)
output=ROOT/'dist/DBF-MCM-Standalone-0.1.56.zip'
entry_name='mods/dbf_mcm/startup'
envelope=struct.pack('<II',len(source.encode()),2)+source.encode()
archive=write({hash_name(entry_name):envelope})
assert read(archive)[hash_name(entry_name)][1]==envelope
manager={'Version':1,'Guid':'e9c84b37-7a48-42ad-9a72-3a43f06b96e1','Name':'DBF-MCM Standalone 0.1.56','Description':'Requires Bingus Shared Loader v15 or newer / API 1. Enable both and deploy.','Options':[{'Name':'DBF-MCM Standalone 0.1.56','Description':'Requires Bingus Shared Loader v15 or newer / API 1. Enable both and deploy.','Include':['Addon']}]}
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
 z.writestr('manifest.json',json.dumps(manager,indent=2))
 z.writestr('Addon/9ba626afa44a3aa3.patch_0',archive)
 z.writestr('Addon/9ba626afa44a3aa3.patch_0.stream',b'')
 z.writestr('Addon/9ba626afa44a3aa3.patch_0.gpu_resources',b'')
with zipfile.ZipFile(output,'a',zipfile.ZIP_DEFLATED) as z:
 z.write(ROOT/'README.md','README.md');z.write(ROOT/'docs/CREDITS.md','CREDITS.md');z.write(ROOT/'src/native_ui/LICENSE','LICENSE-CowboyBingus.txt');z.write(ROOT/'docs/AUTHOR-GUIDE.md','AUTHOR-GUIDE.md');z.write(ROOT/'docs/RELEASE-0.1.56.md','RELEASE-NOTES.md');z.write(ROOT/'docs/RELEASE-0.1.56.md','docs/RELEASE-0.1.56.md');z.write(ROOT/'docs/INTEGRATIONS.md','docs/INTEGRATIONS.md');z.write(ROOT/'tools/lua_archive.py','Source/tools/lua_archive.py');z.write(ROOT/'docs/INSTALL-STANDALONE.md','INSTALL.md');z.write(ROOT/'src/startup.lua','Source/startup.lua');z.write(ROOT/'build_standalone.py','Source/build_standalone.py')
 for name in ['tools/hud_plus_archive.py','tools/hud_plus_patch.py','tools/hud_plus_verify.py','tools/runtime_guard.py','tools/deploy_guard.ps1','tools/install_hud_plus_bridge.ps1','src/core.lua','src/integrations/hud_plus.lua','src/integrations/hud_plus_runtime.lua']:
  z.write(ROOT/name,name)
with zipfile.ZipFile(output) as z:assert z.testzip() is None;assert len(z.namelist())==len(set(z.namelist()))
print('PASS startup Lua compilation and ZIP integrity; live startup not verified');print(output)
