local core=assert(loadfile('src/core.lua'))();local menu=assert(loadfile('src/menu.lua'))()
local api=core.new();local changes=0
-- This fixture is a provider-owned specification, not MCM's classification.
local spec={id='lll_management',name='Live Lua Loader',categories={{id='source_lll_live',name='LLL live scripts (1 loaded / 1)'},{id='source_mdl',name='MDL registry (0 loaded / 1)'}},pages={
 {id='overview',name='Overview',require_confirmation=false,controls={{id='refresh',type='button',label='Refresh',on_activate=function()changes=changes+1 end}}},
 {id='entry_1',name='[Loaded] Example',category='source_lll_live',require_confirmation=false,controls={{id='entry_1_enabled',type='toggle',label='Enabled',default=true,on_change=function()changes=changes+1 end}}},
 {id='external_1',name='[Disabled] Other',category='source_mdl',controls={{type='text',label='Status: disabled'}}}}}
local h=api.register(spec);local m=menu.new(api);local nodes=m.navigation(api.mods.lll_management)
local category,page=false,false
for _,n in ipairs(nodes)do if n.kind=='category' and n.category.id=='source_lll_live'then category=true end;if n.kind=='page' and n.page.id=='entry_1' and n.page.name=='[Loaded] Example'then page=true end end
assert(category and page);assert(h.set('entry_1_enabled',false) and h.get('entry_1_enabled')==false and changes==1)
assert(h.activate('refresh') and changes==2)
m.visible=true;assert(#m.compose(1920,1080)>0)
print('PASS MCM consumes provider categories/status labels verbatim and preserves option IDs, setters and Refresh')
