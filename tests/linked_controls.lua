local Core=dofile('src/core.lua');local Grouping=dofile('src/grouping.lua');local Menu=dofile('src/menu.lua')
local api=Core.new(nil,nil,Grouping)
local a=api.register({id='armor',name='Epic LUT',categories={{id='quick',name='Quick Load'},{id='armor',name='Armor'},{id='helmet',name='Helmet'}},pages={{id='quick',name='Quick Load',category='quick',require_confirmation=false,controls={{type='text',text_role='selection',label='Source rows',swatches={{row=1,rgb={255,0,0}},{row=2,rgb={0,255,0}}}},{id='extras',type='section',label='Extras',collapsed=true,children={{id='preserve',type='toggle',label='Preserve',default=false}}}}},{id='armor',name='Equipped armor',category='armor',require_confirmation=false,controls={{id='enabled',type='toggle',label='Enabled',default=false}}}}})
local h=api.register({id='helmet',name='Epic LUT - Helmet',parent_name='Epic LUT',categories={{id='helmet',name='Helmet'}},pages={{id='helmet',name='Equipped helmet',category='helmet',require_confirmation=false,controls={{id='enabled',type='toggle',label='Enabled',default=false}}}}})
local page=api.mods.armor.pages[1]
page.controls[#page.controls+1]={id='quick_armor',type='toggle',label='Armor enabled',source_mod_id='armor',source_control_id='enabled',groups={}}
page.controls[#page.controls+1]={id='quick_helmet',type='toggle',label='Helmet enabled',source_mod_id='helmet',source_control_id='enabled',groups={}}
local composite=api.list()[1];assert(composite.handle.set('quick_armor',true)and a.get('enabled')and not h.get('enabled'))
assert(composite.handle.set('quick_helmet',true)and h.get('enabled'));assert(a.set('enabled',false)and not composite.handle.get('quick_armor'))
assert(not api.mods.armor.values.quick_armor and not api.mods.armor.values.quick_helmet,'Linked aliases created duplicate authoritative flags')
page.controls[#page.controls].disabled=true;composite=api.list()[1];assert(not pcall(composite.handle.set,'quick_helmet',false),'Disabled alias was writable')
local menu=Menu.new(api);menu.visible=true;local nodes=menu.navigation(composite);assert(nodes[1].category.name=='Quick Load')
local commands=menu.compose(1920,1080);assert(#commands>0)
h.unregister();assert(#api.list()==1 and api.list()[1].controls.quick_armor and not api.list()[1].controls.quick_helmet,'Stale linked owner retained')
print('PASS: shared master aliases are bidirectional and independent without duplicate flags; disabled/stale refs rejected, Quick Load is first, and display-only swatches render')
