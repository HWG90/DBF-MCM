"""Bundle a standalone MDL API 2 mod; optional local installation only."""
from pathlib import Path
import argparse, shutil, os, zipfile, subprocess, sys, hashlib
from tools.runtime_guard import require_physical_runtime
require_physical_runtime()
ROOT=Path(__file__).resolve().parent
VERSION=(ROOT/'VERSION').read_text().strip()
parser=argparse.ArgumentParser();parser.add_argument('--install',action='store_true');args=parser.parse_args()
if args.install:parser.error('Python installation is disabled. Build with build.ps1, then use the native PowerShell deploy.ps1 entrypoint.')
parts=['local MCM={}\n']
for name in ['core','store','console','commands','preferences','platform','view','capture','camera_input','compat','legacy','bindings','authoring','grouping','framework']:
    parts.append(f'MCM.{name}=(function()\n'+(ROOT/'src'/f'{name}.lua').read_text(encoding='utf-8')+'\nend)()\n')
for name in ['theme','text','font','layout','branding','input','render']:
    parts.append(f'MCM.ui_{name}=(function()\n'+(ROOT/'src/ui'/f'{name}.lua').read_text(encoding='utf-8')+'\nend)()\n')
for name,path in [('native_memory','native_ui/bingus_memory'),('native_runtime','native_ui/bingus_runtime'),('native_entry','integrations/native_entry'),('hud_plus','integrations/hud_plus'),('hud_plus_runtime','integrations/hud_plus_runtime')]:
    parts.append(f'MCM.{name}=(function()\n'+(ROOT/'src'/f'{path}.lua').read_text(encoding='utf-8')+'\nend)()\n')
parts.append('MCM.menu=(function(...)\n'+(ROOT/'src/menu.lua').read_text(encoding='utf-8')+'\nend)({theme=MCM.ui_theme,text=MCM.ui_text,layout=MCM.ui_layout,branding=MCM.ui_branding,input=MCM.ui_input,render=MCM.ui_render})\n')
parts.append('return (function()\n'+(ROOT/'src/adapter.lua').read_text(encoding='utf-8')+'\nend)()\n')
dist=ROOT/'dist/dbf_mcm';dist.mkdir(parents=True,exist_ok=True)
(dist/'settings').mkdir(exist_ok=True)
(dist/'mod.lua').write_text(''.join(parts),encoding='utf-8')
native_name=(ROOT/'native/build/library.txt').read_text(encoding='utf-8').strip()
shutil.copy2(ROOT/'native/build'/native_name,dist/native_name)
(dist/'library.txt').write_text(native_name)
lll_output=ROOT/'dist/lll-package'
subprocess.run([sys.executable,str(ROOT/'tools/build_lll.py'),'--output',str(lll_output),'--version',VERSION],check=True)
modular=lll_output/'dbf_mcm'
files={str(path.relative_to(modular)).replace('\\','/'):path.read_bytes() for path in modular.rglob('*') if path.is_file() and path.name!='FILES-SHA256.txt'}
files['mod.lua']=(dist/'mod.lua').read_bytes()
files['FILES-SHA256.txt']=''.join(hashlib.sha256(body).hexdigest()+'  '+name+'\n' for name,body in sorted(files.items())).encode()
with zipfile.ZipFile(ROOT/f'dist/ModConfigurationMenu-Preview-{VERSION}.zip','w',zipfile.ZIP_DEFLATED) as z:
    for name,body in files.items():z.writestr('dbf_mcm/'+name,body)
    z.writestr('dbf_mcm/settings/','')
    for name in ['README.md','docs/AUTHOR-GUIDE.md','docs/INSTALL-STANDALONE.md','docs/CREDITS.md','src/native_ui/LICENSE','docs/INTEGRATIONS.md','docs/ARCHITECTURE.md','docs/API.md','docs/DIAGNOSTICS.md','docs/MCM-REFERENCE.md','docs/INPUT-CAPTURE.md','examples/example.lua','native/input_guard.c','native/build.py','native/test_input_guard.c']:
        z.write(ROOT/name,name)
    for name in ['tools/hud_plus_archive.py','tools/hud_plus_patch.py','tools/hud_plus_verify.py','tools/runtime_guard.py','tools/deploy_guard.ps1','tools/install_hud_plus_bridge.ps1','src/core.lua','src/integrations/hud_plus.lua','src/integrations/hud_plus_runtime.lua']:
        z.write(ROOT/name,name)
    z.write(ROOT/f'docs/RELEASE-{VERSION}.md',f'docs/RELEASE-{VERSION}.md')
    z.write(ROOT/'docs/LLL-MODULAR.md','docs/LLL-MODULAR.md')
print(ROOT/f'dist/ModConfigurationMenu-Preview-{VERSION}.zip')
