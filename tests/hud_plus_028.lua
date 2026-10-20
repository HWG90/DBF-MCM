local Schema=dofile('src/integrations/hud_plus_028_schema.lua')
local Modern=dofile('src/integrations/hud_plus_028.lua')
local Core=dofile('src/core.lua');local Integration=dofile('src/integrations/hud_plus.lua')
-- These two pure modules were extracted from the exact 0.2.8 package into dist,
-- never executed as the full HUD+ product or redistributed in MCM.
local Settings=dofile('dist/hud-plus-028-research/core.settings.lua')
local Runtime=dofile('dist/hud-plus-028-research/core.runtime.lua')
local entries={};for i,e in ipairs(Schema)do local row={};for _,key in ipairs({'id','default','title','description','group','step','choices','range'})do row[key]=e[key]end;entries[i]=row end
local s=Settings.new(entries);local text=s:serialize();local writes,fail=0,false
s:bind(function()return text end,function(v)if fail then return nil,'disk failure'end;text=v;writes=writes+1;return true end,function()return 1 end);s:load(text)
local product={settings=s,menu={rows={}},step=function()end,close=function()end}
local env={update=function()end};local runtime=Runtime.new(product):install(env)
local provider=Modern.new(Schema,env);local b=assert(provider.poll());assert(b.version=='0.2.8'and #b.entries()==33)
for i=1,10000 do assert(provider.poll()==b)end;assert(provider.diagnostic().scans==1,'unchanged update rescanned')
local api=Core.new();local integration=Integration.new(api);assert(integration.poll(b))
local mod=assert(api.mods.hud_plus);local id=Integration.control_id('hud.world3d.size')
local ok,why=mod.handle.set(id,1.5);assert(ok,tostring(why));assert(writes==1 and s.values['hud.world3d.size']==1.5,'save count='..writes..' value='..tostring(s.values['hud.world3d.size']))
assert(mod.handle.set(id,1.5));assert(writes==1,'unchanged option saved twice')
assert(not b.apply({['hud.world3d.tilt_mix']=.3},b.generation),'hidden option accepted')
-- Native editor and disk errors must not commit a competing or partial edit.
s:begin();s:edit('hud.world3d.size',.75);assert(not mod.handle.set(id,1.4));assert(s.editing['hud.world3d.size']==.75 and writes==1);s:cancel()
product.menu.rows.content={};assert(not mod.handle.set(id,1.4));product.menu.rows.content=nil
fail=true;assert(not mod.handle.set(id,1.4));assert(s.values['hud.world3d.size']==1.5 and mod.handle.get(id)==1.5);fail=false
-- A native/file edit is mirrored without writing back from MCM.
s.values['hud.world3d.size']=.8;assert(integration.poll(b));assert(mod.handle.get(id)==.8 and writes==1)
local choice=Integration.control_id('hud.world3d.lock')
assert(mod.handle.set(choice,2)and s.values['hud.world3d.lock']==1,'zero-based native enum conversion failed')
text=text:gsub('hud%.corpse=1','hud.corpse=0')
assert(mod.handle.set(id,1.1));assert(s.values['hud.corpse']==0,'concurrent native file edit overwritten')
local invalid={};for i,e in ipairs(Schema)do invalid[i]=e end
invalid[1]={id=Schema[1].id,default=99}
assert(not Modern.new(invalid,env).poll(),'unverified schema accepted')
local previous=env.update;env.update=function(...)return previous(...)end
local b2=assert(provider.poll());assert(not b.alive()and b2~=b);assert(integration.poll(b2))
local old=product;runtime.program={step=function()end,close=function()end}
assert(not provider.poll()and not b2.alive());assert(not integration.poll(b2))
runtime.program=old;local b3=assert(provider.poll());assert(integration.poll(b3))
runtime:stop();assert(not provider.poll()and not b3.alive())
print('PASS actual 0.2.8 settings/runtime: automatic discovery, 33 controls, 10000 idle polls, authoritative saves, conflicts/failures, native sync and owner replacement/retirement')
