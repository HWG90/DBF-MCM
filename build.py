"""Bundle a standalone MDL API 2 mod; optional local installation only."""
from pathlib import Path
import argparse, shutil, os, zipfile
from tools.runtime_guard import require_physical_runtime
require_physical_runtime()
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--install',action='store_true');args=parser.parse_args()
if args.install:parser.error('Python installation is disabled. Build with build.ps1, then use the native PowerShell deploy.ps1 entrypoint.')
parts=['local MCM={}\n']
for name in ['core','store','console','preferences','platform','view','capture','compat','legacy','authoring','grouping','framework']:
    parts.append(f'MCM.{name}=(function()\n'+(ROOT/'src'/f'{name}.lua').read_text(encoding='utf-8')+'\nend)()\n')
for name in ['theme','text','input','render']:
    parts.append(f'MCM.ui_{name}=(function()\n'+(ROOT/'src/ui'/f'{name}.lua').read_text(encoding='utf-8')+'\nend)()\n')
parts.append('MCM.menu=(function(...)\n'+(ROOT/'src/menu.lua').read_text(encoding='utf-8')+'\nend)({theme=MCM.ui_theme,text=MCM.ui_text,input=MCM.ui_input,render=MCM.ui_render})\n')
parts.append('return (function()\n'+(ROOT/'src/adapter.lua').read_text(encoding='utf-8')+'\nend)()\n')
dist=ROOT/'dist/dbf_mcm';dist.mkdir(parents=True,exist_ok=True)
(dist/'settings').mkdir(exist_ok=True)
(dist/'mod.lua').write_text(''.join(parts),encoding='utf-8')
native_name=(ROOT/'native/build/library.txt').read_text(encoding='utf-8').strip()
shutil.copy2(ROOT/'native/build'/native_name,dist/native_name)
(dist/'library.txt').write_text(native_name)
with zipfile.ZipFile(ROOT/'dist/ModConfigurationMenu-Preview-0.1.53.zip','w',zipfile.ZIP_DEFLATED) as z:
    z.write(dist/'mod.lua','dbf_mcm/mod.lua');z.writestr('dbf_mcm/settings/','')
    z.write(dist/native_name,'dbf_mcm/'+native_name);z.write(dist/'library.txt','dbf_mcm/library.txt')
    for name in ['README.md','docs/AUTHOR-GUIDE.md','docs/INSTALL-STANDALONE.md','docs/CREDITS.md','docs/RELEASE-0.1.53.md','docs/ARCHITECTURE.md','docs/API.md','docs/DIAGNOSTICS.md','docs/MCM-REFERENCE.md','docs/INPUT-CAPTURE.md','examples/example.lua','native/input_guard.c','native/build.py','native/test_input_guard.c']:
        z.write(ROOT/name,name)
print(ROOT/'dist/ModConfigurationMenu-Preview-0.1.53.zip')
