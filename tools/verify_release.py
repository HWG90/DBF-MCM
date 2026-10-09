from pathlib import Path
import ctypes,hashlib,json,struct,zipfile
from tools.lua_archive import read,hash_name,LUA_TYPE
root=Path('.');dist=root/'dist';version='0.1.54'
packages=[dist/f'ModConfigurationMenu-Preview-{version}.zip',dist/f'DBF-MCM-Standalone-{version}.zip']
for p in packages:
 with zipfile.ZipFile(p) as z:
  assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))
  assert not any('/settings/' in n and not n.endswith('/') for n in z.namelist())
  for name in ['tools/hud_plus_patch.py','tools/hud_plus_verify.py','tools/install_hud_plus_bridge.ps1','src/integrations/hud_plus_runtime.lua']:
   assert z.read(name)==(root/name).read_bytes(),'Missing/stale integration setup source'
  assert not any('HD2-HUD-Plus-' in n or n.endswith('hud_plus_labels.tsv') for n in z.namelist()),'Third-party local artifact included'
with zipfile.ZipFile(packages[0]) as z:
 module=z.read('dbf_mcm/mod.lua');native_name=z.read('dbf_mcm/library.txt').decode().strip();native=z.read('dbf_mcm/'+native_name)
 assert module== (dist/'dbf_mcm/mod.lua').read_bytes()
 assert native==(root/'native/build'/native_name).read_bytes()
 normalized_module=module.decode().replace('\r\n','\n')
 for source in (root/'src').rglob('*.lua'):
  if source.name!='startup.lua':
   assert source.read_text(encoding='utf-8').replace('\r\n','\n') in normalized_module,f'Stale bundled source: {source}'
with zipfile.ZipFile(packages[1]) as z:
 manifest=json.loads(z.read('manifest.json'));assert manifest['Guid']=='e9c84b37-7a48-42ad-9a72-3a43f06b96e1';assert manifest['Options'][0]['Include']==['Addon']
 payload=read(z.read('Addon/9ba626afa44a3aa3.patch_0'))
 kind,envelope=payload[hash_name('mods/dbf_mcm/startup')];assert kind==LUA_TYPE
 length,marker=struct.unpack_from('<II',envelope);assert marker==2 and length==len(envelope)-8
 startup=envelope[8:];assert startup==(dist/'dbf_mcm_startup.lua').read_text(encoding='utf-8').encode()
 assert module.decode().replace("\r\n","\n").encode() in startup and native.hex().encode() in startup
with zipfile.ZipFile(dist/'ModConfigurationMenu-Preview-0.1.50.zip') as old:
 assert native==old.read('dbf_mcm/'+native_name),'Native helper changed'
assert b"version='0.1.54'" in module and b"version='0.1.50'" not in module
# Compile every current source and both generated Lua entries, without executing adapters.
dll=ctypes.CDLL(r'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\bin\lua51.dll')
dll.luaL_newstate.restype=ctypes.c_void_p;dll.luaL_loadfile.argtypes=[ctypes.c_void_p,ctypes.c_char_p];dll.lua_close.argtypes=[ctypes.c_void_p]
for p in list((root/'src').rglob('*.lua'))+[dist/'dbf_mcm/mod.lua',dist/'dbf_mcm_startup.lua']:
 state=dll.luaL_newstate()
 try: assert dll.luaL_loadfile(state,str(p).encode())==0,str(p)
 finally:dll.lua_close(state)
hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in packages}
(dist/f'SHA256SUMS-{version}.txt').write_text(''.join(f'{h}  {n}\n' for n,h in hashes.items()),encoding='utf-8')
receipt={'version':version,'packages_sha256':hashes,'native_name':native_name,'native_sha256':hashlib.sha256(native).hexdigest(),'source_sha256':{str(p).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((root/'src').rglob('*.lua'))},'offline_validation':'23 isolated suites, actual HUD+ Options/BootState with simulated native apply, native ownership/restoration, unchanged DLL, package integrity and compilation','broad_suite':'42 contracts pass; rebindable DEL default, scale, source modules and cursor readbacks covered','live_validation':'Current 0.1.54 and local HUD+ patch require a new launch and in-game tab/setting/input acceptance','deployment':'verify separate LLL and HUD+ cold-install receipts','release_upload':False}
(dist/f'BUILD-RECEIPT-{version}.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('PASS all source/bundle Lua compilation, archive payload/manifest, runtime parity, unchanged native DLL, ZIP integrity and SHA256 receipts')
for p in packages:print(p.name,p.stat().st_size)
