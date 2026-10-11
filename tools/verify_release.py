"""Verify current BSL and shared MDL/LLL release packages without game attachment."""
from pathlib import Path
import ctypes, hashlib, json, struct, zipfile
from tools.lua_archive import read, hash_name, LUA_TYPE

root=Path(__file__).resolve().parents[1]
dist=root/'dist'; version=(root/'VERSION').read_text().strip()
packages=[dist/f'ModConfigurationMenu-Preview-{version}.zip',dist/f'DBF-MCM-Standalone-{version}.zip']
sha=lambda body:hashlib.sha256(body).hexdigest()
for path in packages:
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None and len(archive.namelist())==len(set(archive.namelist()))
        assert not any('/settings/' in name and not name.endswith('/') for name in archive.namelist())
        assert not any(name.endswith('.log') or '/.git/' in name or 'Future Project' in name for name in archive.namelist())
        assert not any('HD2-HUD-Plus-' in name or name.endswith('hud_plus_labels.tsv') for name in archive.namelist())
        for name in ['tools/hud_plus_patch.py','tools/hud_plus_verify.py','tools/install_hud_plus_bridge.ps1','src/integrations/hud_plus_runtime.lua']:
            assert archive.read(name)==(root/name).read_bytes(), 'Stale public integration setup source'
        assert archive.read(f'docs/RELEASE-{version}.md')==(root/f'docs/RELEASE-{version}.md').read_bytes()

with zipfile.ZipFile(packages[0]) as archive:
    module=archive.read('dbf_mcm/mod.lua')
    assert module==(dist/'dbf_mcm/mod.lua').read_bytes()
    native_name=archive.read('dbf_mcm/library.txt').decode().strip()
    native=archive.read('dbf_mcm/'+native_name)
    assert native_name=='mcm_input_'+sha((root/'native/input_guard.c').read_bytes())[:12]+'.dll'
    assert native==(root/'native/build'/native_name).read_bytes()
    assert f"version='{version}'".encode() in module
    normalized=module.decode().replace('\r\n','\n')
    for source in (root/'src').rglob('*.lua'):
        if source.name!='startup.lua':
            assert source.read_text().replace('\r\n','\n') in normalized, 'Stale bundled source: '+str(source)
    manifest=json.loads(archive.read('dbf_mcm/manifest.json'))
    assert manifest['version']==version and manifest['lll']['entry']=='main.lua'
    assert manifest['lll']['restart_only'] and manifest['lll']['retain_until_exit']
    defaults=json.loads(archive.read('dbf_mcm/config/defaults.cfg'))
    assert defaults['verbose_registration'] is False
    modular=dist/'lll-package/dbf_mcm'
    for name in manifest['lll']['modules']:
        assert archive.read('dbf_mcm/'+name)==(modular/name).read_bytes()
        if name not in ['src/adapter.lua','src/preferences.lua']:
            assert archive.read('dbf_mcm/'+name)==(root/name).read_bytes()
    main=archive.read('dbf_mcm/main.lua').decode()
    assert main==(modular/'main.lua').read_text()
    for name in ['commands','ui_font','ui_layout','ui_branding']:
        assert main.index('MCM.'+name+'=')<main.index('MCM.menu=')
    for line in archive.read('dbf_mcm/FILES-SHA256.txt').decode().splitlines():
        digest,name=line.split('  ',1)
        assert sha(archive.read('dbf_mcm/'+name))==digest, 'Bad modular inventory: '+name
    assert 'mod.lua' in archive.read('dbf_mcm/FILES-SHA256.txt').decode()

with zipfile.ZipFile(packages[1]) as archive:
    manifest=json.loads(archive.read('manifest.json'))
    assert manifest['Guid']=='e9c84b37-7a48-42ad-9a72-3a43f06b96e1' and manifest['Options'][0]['Include']==['Addon']
    assert version in manifest['Name']
    payload=read(archive.read('Addon/9ba626afa44a3aa3.patch_0'))
    kind,envelope=payload[hash_name('mods/dbf_mcm/startup')]
    assert kind==LUA_TYPE
    length,marker=struct.unpack_from('<II',envelope)
    assert marker==2 and length==len(envelope)-8
    startup=envelope[8:]
    assert startup==(dist/'dbf_mcm_startup.lua').read_text().encode()
    assert module.decode().replace('\r\n','\n').encode() in startup and native.hex().encode() in startup

dll=ctypes.CDLL(r'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\bin\lua51.dll')
dll.luaL_newstate.restype=ctypes.c_void_p
dll.luaL_loadfile.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
dll.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];dll.lua_tolstring.restype=ctypes.c_char_p
dll.lua_close.argtypes=[ctypes.c_void_p]
sources=list((root/'src').rglob('*.lua'))+[dist/'dbf_mcm/mod.lua',dist/'dbf_mcm_startup.lua']+list((dist/'lll-package/dbf_mcm').rglob('*.lua'))
for path in sources:
    state=dll.luaL_newstate()
    try:
        assert dll.luaL_loadfile(state,str(path).encode())==0, str(path)+': '+str(dll.lua_tolstring(state,-1,None))
    finally:
        dll.lua_close(state)
hashes={path.name:sha(path.read_bytes()) for path in packages}
(dist/f'SHA256SUMS-{version}.txt').write_text(''.join(f'{digest}  {name}\n' for name,digest in hashes.items()))
receipt={'version':version,'packages_sha256':hashes,'native_name':native_name,'native_sha256':sha(native),'source_sha256':{str(path.relative_to(root)).replace('\\','/'):sha(path.read_bytes()) for path in sorted((root/'src').rglob('*.lua'))},'offline_validation':f'{len(sources)} Lua sources/entries compiled; ZIP, bundled source, BSL payload, shared MDL/LLL entry, module inventory and native source parity passed','live_validation':'Main game font and console behavior user-confirmed in LLL. Latest sidebar/dropdown pass rendered offline and installed; other routes retain preview status.','deployment':'Release packaging does not change installed game/mod/settings files','release_upload':False}
(dist/f'BUILD-RECEIPT-{version}.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('PASS '+receipt['offline_validation'])
for path in packages:print(path.name,path.stat().st_size,hashes[path.name])
