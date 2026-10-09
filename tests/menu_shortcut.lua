local Core=dofile('src/core.lua');local Menu=dofile('src/menu.lua');local Prefs=dofile('src/preferences.lua')
local api=Core.new();local menu=Menu.new(api);local settings,actions;actions={get=function(key)return settings and settings.get(key)end}
local spec={id='framework',name='MCM',pages={Prefs.page(function(key)assert(Prefs.apply(api,menu,settings,key,actions))end,actions)}}
settings=api.register(spec);assert(Prefs.apply(api,menu,settings,nil,actions));api.settings_mod_id=settings.id;api.settings_page_id='mcm_settings'
api.register({id='example',name='Example',pages={{id='p',name='Page',require_confirmation=false,controls={{id='enabled',type='toggle',label='Enabled',default=true}}}}})
local keys={};local input={down=function(code)return keys[code]or false end,mouse=function()return nil end}
keys[46]=true;menu.tick(input);assert(menu.visible);menu.tick(input);assert(menu.visible);keys[46]=false;menu.tick(input)
assert(settings.set('menu_toggle_key',121));keys[46]=true;menu.tick(input);assert(menu.visible);keys[46]=false;keys[121]=true;menu.tick(input);assert(not menu.visible)
keys[121]=false;menu.tick(input);keys[121]=true;menu.tick(input);assert(menu.visible);keys[121]=false;menu.tick(input)
menu.text_edit={text='abc'};menu.key(121);assert(menu.visible and menu.text_edit);menu.key(46);assert(menu.visible and menu.text_edit.text=='');menu.key(27)
menu.capture=api.mods.framework.controls.menu_toggle_key;menu.selected=2;menu.page=1;menu.key(9)
assert(menu.visible and settings.get('menu_toggle_key')==121 and api.menu_toggle_key==121,'conflicting captured key mutated state or closed menu')
menu.selected=1;menu.page=1;menu.row=1;menu.focus='settings';assert(menu.open_settings());assert(api.list()[menu.selected].id=='framework')
assert(menu.open_settings());assert(api.list()[menu.selected].id=='example' and menu.row==1 and menu.focus=='settings')
menu.key(113);assert(api.list()[menu.selected].id=='example','F2 unexpectedly opened settings')
menu.visible=true;local before=menu.compose(1920,1080);local label,size
for _,c in ipairs(before)do if c.type=='text'and c.text=='Enabled'then size=c.size end end
assert(settings.set('font_size',26));local after=menu.compose(1920,1080)
for _,c in ipairs(after)do if c.type=='text'and c.text=='Enabled'then assert(math.abs(c.size-size*1.3)<.001)end end
assert(settings.set('ui_scale',150));menu.compose(800,600);local b=menu.window_bounds
assert(b.x>=0 and b.y>=0 and b.x+b.w<=800.001 and b.y+b.h<=600.001)
local button;for _,c in ipairs(menu.compose(1920,1080))do if c.ui_role=='settings_button'then button=c end end;assert(button)
local pending=api.register({id='pending',name='Pending',pages={{id='p',name='Pending',require_confirmation=true,controls={{id='enabled',type='toggle',label='Enabled',default=false}}}}})
for index,mod in ipairs(api.list())do if mod.id=='pending'then menu.selected=index end end
menu.page=1;menu.row=1;menu.focus='settings';assert(pending.edit('enabled',true))
menu.key(120);menu.key(119);menu.key(36)
assert(not pending.get('enabled') and pending.preview('enabled'),'obsolete Apply/Discard/Home key changed draft')
local apply;for _,command in ipairs(menu.compose(1920,1080))do if command.type=='text'and command.text=='APPLY'then apply=command end end;assert(apply)
menu.tick({down=function(code)return code==1 end,mouse=function()return apply.x,apply.y end})
assert(pending.get('enabled') and next(api.mods.pending.pages[1].pending)==nil,'Apply button did not save draft')
print('PASS authoritative rebind, held edges, editor ownership, Settings navigation and scaling')
