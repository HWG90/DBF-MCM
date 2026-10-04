"""Build the Shared Loader startup variant with an embedded native input library."""
from pathlib import Path
import argparse, importlib.util, subprocess, sys, ctypes, zipfile
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--addon-builder',type=Path,required=True);args=parser.parse_args()
subprocess.run([sys.executable,str(ROOT/'build.py')],check=True)
spec=importlib.util.spec_from_file_location('addon_builder',args.addon_builder);builder=importlib.util.module_from_spec(spec);sys.path.insert(0,str(args.addon_builder.parent));spec.loader.exec_module(builder)
name=(ROOT/'native/build/library.txt').read_text().strip()
native=(ROOT/'native/build'/name).read_bytes()
module=(ROOT/'dist/dbf_mcm/mod.lua').read_text(encoding='utf-8')
source=(ROOT/'src/startup.lua').read_text(encoding='utf-8').replace('__NATIVE_NAME__',name).replace('__NATIVE_HEX__',native.hex()).replace('-- __MODULE__',module)
entry=ROOT/'dist/dbf_mcm_startup.lua';entry.write_text(source,encoding='utf-8')
dll=ctypes.CDLL(r'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\bin\lua51.dll');dll.luaL_newstate.restype=ctypes.c_void_p;state=dll.luaL_newstate();dll.luaL_loadfile.argtypes=[ctypes.c_void_p,ctypes.c_char_p];dll.lua_close.argtypes=[ctypes.c_void_p]
try:assert dll.luaL_loadfile(state,str(entry).encode())==0,'Startup Lua compilation failed'
finally:dll.lua_close(state)
output=ROOT/'dist/DBF-MCM-Standalone-0.1.49.zip'
builder.build_addon('mods/dbf_mcm/startup',source.encode(),'e9c84b37-7a48-42ad-9a72-3a43f06b96e1',output,display_name='DBF-MCM Standalone 0.1.49')
with zipfile.ZipFile(output,'a',zipfile.ZIP_DEFLATED) as z:
 z.write(ROOT/'README.md','README.md');z.write(ROOT/'docs/INSTALL-STANDALONE.md','INSTALL.md');z.write(ROOT/'src/startup.lua','Source/startup.lua');z.write(ROOT/'build_standalone.py','Source/build_standalone.py')
with zipfile.ZipFile(output) as z:assert z.testzip() is None;assert len(z.namelist())==len(set(z.namelist()))
print('PASS startup Lua compilation and ZIP integrity; live startup not verified');print(output)
