local Core=dofile('src/core.lua');local Preferences=dofile('src/preferences.lua')
local count=0
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));count=count+1;print('PASS '..name)end
local function setup(saved,fail_save)
 local saved_values={};for key,value in pairs(saved or {})do saved_values[key]=value end
 local writes=0;local api=Core.new({load=function(id)if id=='mcm_custom_palette'then return {}end;assert(id=='mcm');return saved_values end,
  save=function(id,values)assert(id=='mcm');writes=writes+1;if fail_save and fail_save()then return false,'disk unavailable'end;saved_values=values;return true end})
 local menu={};local handle;local changed={};local actions={}
 actions.get=function(key)return handle and handle.get(key)end
 actions.reset_window=function()local ok,err=Preferences.reset_window(menu,handle);assert(ok,err);return err end
 local github=0;actions.open_github=function()github=github+1;return 'GitHub opened'end
 local spec={id='mcm',name='Mod Configuration Menu',pages={{id='overview',name='Overview',require_confirmation=false,controls={{id='existing',type='toggle',label='Existing framework value',default=true}}}}}
 spec.pages[#spec.pages+1]=Preferences.page(function(key,value)local ok,err=Preferences.apply(api,menu,handle,key,actions);assert(ok,err);changed[#changed+1]={key=key,value=value}end,actions)
 handle=api.register(spec)
 return {api=api,menu=menu,handle=handle,actions=actions,spec=spec,changed=changed,
  writes=function()return writes end,saved=function()return saved_values end,github=function()return github end}
end
test('settings use the existing framework registration and persist immediately',function()
 local s=setup();assert(#s.api.list()==1 and #s.api.mods.mcm.pages==2)
 local page=s.api.mods.mcm.pages[2];assert(page.id=='mcm_settings' and not page.require_confirmation)
 s.api.ui_keys={settings=113,apply=120,discard=119,default=36}
 assert(Preferences.apply(s.api,s.menu,s.handle,nil,s.actions))
 assert(s.api.menu_toggle_key==46 and not next(s.api.ui_keys))
 for _,key in ipairs({'settings_key','apply_key','discard_key','default_key'})do assert(not s.api.mods.mcm.controls[key])end
 assert(s.menu.window_width==1500 and s.menu.window_height==820 and s.menu.ui_scale==1 and s.menu.font_scale==1)
 assert(s.handle.edit('menu_toggle_key',121));assert(s.api.menu_toggle_key==121 and s.saved().menu_toggle_key==121)
 assert(s.saved().existing==true and #s.changed==1 and not next(page.pending))
end)
test('all preferences reload through the authoritative saved framework handle',function()
 local saved={menu_toggle_key=121,window_width=1320,window_height=740,ui_scale=125,font_size=24,existing=false}
 local s=setup(saved);assert(Preferences.apply(s.api,s.menu,s.handle,nil,s.actions))
 assert(s.api.menu_toggle_key==121 and not next(s.api.ui_keys))
 assert(s.menu.window_width==1320 and s.menu.window_height==740 and s.menu.default_window_width==1320 and s.menu.default_window_height==740)
 assert(s.menu.ui_scale==1.25 and s.menu.font_scale==1.2 and s.writes()==0 and not s.handle.get('existing'))
 assert(s.handle.set('font_size',25));assert(s.saved().font_size==25 and s.menu.font_scale==1.25)
 local again=setup(s.saved());assert(Preferences.apply(again.api,again.menu,again.handle,nil,again.actions));assert(again.menu.font_scale==1.25)
end)
test('open/close edits reject navigation, modifiers and mouse without secondary shortcuts',function()
 local s=setup();assert(Preferences.apply(s.api,s.menu,s.handle,nil,s.actions))
 for _,key in ipairs({0,1,7,9,13,16,17,18,27,33,34,37,38,39,40,91,92,160,161,162,163,164,165,255})do
  assert(not pcall(s.handle.set,'menu_toggle_key',key),'Accepted reserved shortcut '..key)
 end
 assert(s.writes()==0 and s.api.menu_toggle_key==46)
 for _,key in ipairs({8,46,65,113,119,120,36,121,254})do assert(s.handle.set('menu_toggle_key',key))end
 assert(s.handle.get('menu_toggle_key')==254 and s.api.menu_toggle_key==254)
 assert(not pcall(s.handle.set,'apply_key',254));assert(not pcall(s.handle.set,'settings_key',254))
end)
test('only Open/close exists and independently owned mod bindings stay untouched',function()
 local s=setup();local other=s.api.register({id='other',name='Other mod',storage={load=function()return {}end,save=function()return true end},
  pages={{id='keys',name='Keys',require_confirmation=false,controls={{id='menu_toggle_key',type='keybind',label='Own shortcut',default=121}}}}})
 assert(Preferences.apply(s.api,s.menu,s.handle,nil,s.actions));assert(s.handle.set('menu_toggle_key',121))
 assert(other.get('menu_toggle_key')==121 and #s.api.list()==2)
 assert(s.handle.set('font_size',22));assert(other.get('menu_toggle_key')==121)
 assert(not pcall(s.handle.set,'apply_key',122));assert(not pcall(s.handle.set,'discard_key',119))
end)
test('dimensions and scales respect bounds without resetting unrelated manual geometry',function()
 local s=setup();assert(Preferences.apply(s.api,s.menu,s.handle,nil,s.actions));s.menu.window_width=1600;s.menu.window_height=900;s.menu.window_x=100;s.menu.window_y=80
 assert(s.handle.set('font_size',26));assert(s.menu.font_scale==1.3 and s.menu.window_width==1600 and s.menu.window_height==900)
 assert(s.handle.set('ui_scale',75));assert(s.menu.ui_scale==.75 and s.menu.window_width==1600 and s.menu.window_height==900)
 assert(s.handle.set('window_width',1200));assert(s.menu.window_width==1200 and s.menu.window_height==900 and s.menu.window_x==100)
 assert(s.handle.set('window_height',600));assert(s.menu.window_height==600)
 for _,entry in ipairs({{'window_width',1090},{'window_width',1930},{'window_height',590},{'window_height',1090},{'ui_scale',70},{'ui_scale',155},{'font_size',15},{'font_size',27}})do assert(not pcall(s.handle.set,entry[1],entry[2]))end
 assert(s.handle.set('window_width',1206));assert(s.handle.get('window_width')==1210 and s.menu.window_width==1210)
end)
test('reset and GitHub actions use supplied callbacks without duplicate settings or writes',function()
 local s=setup({window_width=1300,window_height=700});assert(Preferences.apply(s.api,s.menu,s.handle,nil,s.actions))
 s.menu.window_width=1700;s.menu.window_height=950;s.menu.window_x=200;s.menu.window_y=100;s.menu.window_bounds={}
 assert(s.handle.queue('reset_window'));assert(s.menu.window_width==1300 and s.menu.window_height==700 and not s.menu.window_x and not s.menu.window_y and not s.menu.window_bounds)
 assert(s.handle.queue('github_page'));assert(s.github()==1 and s.writes()==0 and s.handle.get('window_width')==1300)
end)
test('failed persistence never updates runtime preferences or unrelated saved values',function()
 local failing=true;local s=setup(nil,function()return failing end);assert(Preferences.apply(s.api,s.menu,s.handle,nil,s.actions))
 local ok,err=s.handle.set('menu_toggle_key',121);assert(not ok and err=='disk unavailable')
 assert(s.api.menu_toggle_key==46 and s.handle.get('menu_toggle_key')==46 and #s.changed==0)
 ok=s.handle.set('window_width',1200);assert(not ok and s.menu.window_width==1500 and s.handle.get('window_width')==1500)
 failing=false;assert(s.handle.set('window_width',1200));assert(s.menu.window_width==1200 and s.saved().existing)
end)
test('invalid loaded open/close repairs once through the same handle and preserves preferences',function()
 local s=setup({menu_toggle_key=27,window_width=1300,existing=false})
 local ok,notice=Preferences.apply(s.api,s.menu,s.handle,nil,s.actions);assert(ok and notice and s.writes()==1)
 assert(s.api.menu_toggle_key==46 and s.handle.get('menu_toggle_key')==46 and s.saved().menu_toggle_key==46)
 assert(s.menu.window_width==1300 and not next(s.api.ui_keys) and not s.handle.get('existing') and not s.saved().existing)
 assert(Preferences.apply(s.api,s.menu,s.handle,nil,s.actions));assert(s.writes()==1)
end)
test('failed repair leaves API, window and saved open/close untouched',function()
 local failing=true;local s=setup({menu_toggle_key=27},function()return failing end)
 s.api.menu_toggle_key=46;s.api.ui_keys={};s.menu.window_width=1450;s.menu.ui_scale=1.1
 local old_keys=s.api.ui_keys;local ok,err=Preferences.apply(s.api,s.menu,s.handle,nil,s.actions)
 assert(not ok and err=='disk unavailable' and s.api.menu_toggle_key==46 and s.api.ui_keys==old_keys)
 assert(s.menu.window_width==1450 and s.menu.ui_scale==1.1 and s.handle.get('menu_toggle_key')==27 and s.saved().menu_toggle_key==27)
 failing=false;assert(Preferences.apply(s.api,s.menu,s.handle,nil,s.actions));assert(s.api.menu_toggle_key==46 and s.handle.get('menu_toggle_key')==46)
end)
test('unavailable action buttons are disabled and malformed runtime snapshots are rejected',function()
 local page=Preferences.page(function()end);assert(page.controls[#page.controls].disabled and page.controls[#page.controls-1].disabled)
 local api,menu={},{};local values=Preferences.defaults();values.font_size=0/0
 local ok=Preferences.apply(api,menu,{get=function(key)return values[key]end});assert(not ok and not next(api) and not next(menu))
 local a=Preferences.defaults();a.menu_toggle_key=1;assert(Preferences.defaults().menu_toggle_key==46)
end)
print(string.format('PASS %d preference contracts: framework ownership, one persisted menu binding, bounds, buttons, repair and failure isolation',count))
