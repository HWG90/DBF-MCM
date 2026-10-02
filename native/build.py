"""Build the local x64 helper with MSVC. Does not attach to the game."""
from pathlib import Path
import subprocess,hashlib,os
root=Path(__file__).resolve().parents[1]
source=root/'native/input_guard.c'
tag=hashlib.sha256(source.read_bytes()).hexdigest()[:12]
out=root/'native/build';out.mkdir(parents=True,exist_ok=True)
name='mcm_input_'+tag+'.dll'
vcvars=Path(os.getenv('DBFMCM_VCVARS',r'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'))
assert vcvars.is_file(),'MSVC x64 build environment missing'
cmd=f'call "{vcvars}" >nul && cl /nologo /LD /O2 /W4 /WX "{source}" /Fo"{out / "input_guard.obj"}" /link /OUT:"{out / name}" user32.lib'
subprocess.run(cmd,shell=True,check=True,cwd=out)
test_cmd=f'call "{vcvars}" >nul && cl /nologo /O2 /W4 /WX "{root / "native/test_input_guard.c"}" /Fo"{out / "test_input_guard.obj"}" /Fe"{out / "test_input_guard.exe"}" /link user32.lib'
subprocess.run(test_cmd,shell=True,check=True,cwd=out)
subprocess.run([str(out/'test_input_guard.exe')],check=True)
(out/'library.txt').write_text(name)
print(out/name)
