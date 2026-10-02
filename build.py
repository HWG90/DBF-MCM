"""Bundle a standalone MDL API 2 mod; optional local installation only."""
from pathlib import Path
import argparse, shutil, os, zipfile
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--install',action='store_true');args=parser.parse_args()
parts=['local MCM={}\n']
for name in ['core','store','menu','view','capture','legacy']:
    parts.append(f'MCM.{name}=(function()\n'+(ROOT/'src'/f'{name}.lua').read_text()+'\nend)()\n')
parts.append('return (function()\n'+(ROOT/'src/adapter.lua').read_text()+'\nend)()\n')
dist=ROOT/'dist/dbf_mcm';dist.mkdir(parents=True,exist_ok=True)
(dist/'settings').mkdir(exist_ok=True)
(dist/'mod.lua').write_text(''.join(parts),encoding='utf-8')
native_name=(ROOT/'native/build/library.txt').read_text().strip()
shutil.copy2(ROOT/'native/build'/native_name,dist/native_name)
(dist/'library.txt').write_text(native_name)
with zipfile.ZipFile(ROOT/'dist/ModConfigurationMenu-Preview-0.1.24.zip','w',zipfile.ZIP_DEFLATED) as z:
    z.write(dist/'mod.lua','dbf_mcm/mod.lua');z.writestr('dbf_mcm/settings/','')
    z.write(dist/native_name,'dbf_mcm/'+native_name);z.write(dist/'library.txt','dbf_mcm/library.txt')
    for name in ['README.md','docs/API.md','docs/MCM-REFERENCE.md','docs/INPUT-CAPTURE.md','examples/example.lua','native/input_guard.c','native/build.py','native/test_input_guard.c']:
        z.write(ROOT/name,name)
if args.install:
    target=Path(os.environ['LOCALAPPDATA'])/'MDL/Helldivers2/Mods/dbf_mcm'
    (target/'settings').mkdir(parents=True,exist_ok=True)
    if not (target/native_name).exists():shutil.copy2(dist/native_name,target/native_name)
    shutil.copy2(dist/'library.txt',target/'library.txt')
    shutil.copy2(dist/'mod.lua',target/'mod.lua.pending')
    os.replace(target/'mod.lua.pending',target/'mod.lua')
    print('Installed local MDL preview:',target)
print(ROOT/'dist/ModConfigurationMenu-Preview-0.1.24.zip')
