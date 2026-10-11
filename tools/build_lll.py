from pathlib import Path
import sys,json,argparse
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=ROOT/'dist/releases/modular');parser.add_argument('--version',default=(ROOT/'VERSION').read_text().strip());args=parser.parse_args()

def package(root,mod_id,title,version,main,modules,extra=None,restart_only=False):
    import hashlib,json,zipfile
    output=args.output;output.mkdir(parents=True,exist_ok=True)
    folder=output/mod_id;folder.mkdir(exist_ok=True)
    files={'main.lua':main.encode('utf-8'),'config/defaults.cfg':b'{}\n'}
    files.update({name:body.encode('utf-8') if isinstance(body,str) else body for name,body in modules.items()})
    files.update(extra or {})
    manifest={'id':mod_id,'name':title,'version':version,'author':'Goose','lll':{'entry':'main.lua','defaults':'config/defaults.cfg','modules':sorted(modules),'restart_only':restart_only,'retain_until_exit':True}}
    files['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
    files['INSTALL.txt']=('Requires LLL R30 or later. Copy '+mod_id+' into LLL/Helldivers2/Mods. Remove the old loose/bundled provider of the same mod before starting. This is a source-layout migration; native DLLs need a normal restart. Existing mod settings are retained. Do not activate alongside the archive provider. '+('This mod remains restart-only; startup hook ownership is unchanged.' if restart_only else 'Lifecycle callbacks and cleanup are preserved.')+'\n').encode()
    files['FILES-SHA256.txt']=''.join(hashlib.sha256(body).hexdigest()+'  '+name+'\n' for name,body in sorted(files.items())).encode()
    for name,body in files.items():
        path=folder/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(body)
    target=output/(mod_id+'-'+version+'-LLL-Modular.zip')
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        for name,body in sorted(files.items()):z.writestr(mod_id+'/'+name,body)
    print(target)
    return target

import re
modules={}
main=['local MCM={}','mod.scope.MCM=MCM']
for name in ['core','store','console','commands','preferences','platform','view','capture','camera_input','compat','legacy','authoring','grouping','framework']:
    path='src/'+name+'.lua';modules[path]=(ROOT/path).read_bytes();main.append('MCM.'+name+'=mod.require("'+path+'")')
for name in ['theme','text','font','layout','branding','input','render']:
    path='src/ui/'+name+'.lua';modules[path]=(ROOT/path).read_bytes();main.append('MCM.ui_'+name+'=mod.require("'+path+'")')
for name,path in [('native_memory','native_ui/bingus_memory'),('native_runtime','native_ui/bingus_runtime'),('native_entry','integrations/native_entry'),('hud_plus','integrations/hud_plus'),('hud_plus_runtime','integrations/hud_plus_runtime')]:
    path='src/'+path+'.lua';modules[path]=(ROOT/path).read_bytes();main.append('MCM.'+name+'=mod.require("'+path+'")')
modules['src/menu.lua']=(ROOT/'src/menu.lua').read_bytes()
main.append('MCM.menu=mod.require("src/menu.lua",{theme=MCM.ui_theme,text=MCM.ui_text,layout=MCM.ui_layout,branding=MCM.ui_branding,input=MCM.ui_input,render=MCM.ui_render})')
adapter=(ROOT/'src/adapter.lua').read_text()
adapter=adapter.replace("local folder=assert(os.getenv('LOCALAPPDATA'),'LOCALAPPDATA unavailable')..'/MDL/Helldivers2/Mods/dbf_mcm/settings'","local legacy_folder=assert(os.getenv('LOCALAPPDATA'),'LOCALAPPDATA unavailable')..'/MDL/Helldivers2/Mods/dbf_mcm/settings';local folder=ctx.config_dir or legacy_folder")
adapter=adapter.replace('local storage=MCM.store.new(folder)','local storage=MCM.store.new(folder);local primary_load=storage.load;local legacy_store=MCM.store.new(legacy_folder);storage.load=function(id)local f=io.open(folder.."/"..id..".ini","rb");if f then f:close();return primary_load(id)end;return legacy_store.load(id)end')
adapter=adapter.replace("ctx.log('MCM preview enabled;",'local console_fields={}\n        for key,value in pairs(MCM.preferences.defaults())do local field=key;console_fields[field]={type=type(value),get=function()return registered.get(field)end,set=function(v)return registered.set(field,v)end}end\n        mod.expose("mcm",{settings=console_fields,verbose_registration={type="boolean",get=api.get_verbose,set=function(v)return MCM.preferences.set_verbose(api,v,mod)end}})\n        ctx.log(\'MCM preview enabled;')
modules['src/adapter.lua']=adapter
main.append('return mod.require("src/adapter.lua")')
source=(ROOT/'src/preferences.lua').read_text()
block=source.split('local defaults={',1)[1].split('}',1)[0]
defaults={key:int(value) for key,value in re.findall(r'(\w+)\s*=\s*(\d+)',block)}
source=source.replace('local ranges=', 'for key,value in pairs(mod.config.preferences or {})do if defaults[key]~=nil then defaults[key]=value end end\nlocal ranges=',1)
modules['src/preferences.lua']=source
native=(ROOT/'native/build/library.txt').read_text().strip()
extra={native:(ROOT/'native/build'/native).read_bytes(),'library.txt':native.encode(),'LICENSE-Bingus.txt':(ROOT/'src/native_ui/LICENSE').read_bytes(),'config/defaults.cfg':(json.dumps({'preferences':defaults,'verbose_registration':False},indent=2)+'\n').encode()}
package(ROOT,'dbf_mcm','DBF MCM',args.version,'\n'.join(main)+'\n',modules,extra,restart_only=True)
