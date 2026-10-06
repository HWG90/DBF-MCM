local core=assert(loadfile('src/core.lua'))();local menu_module=assert(loadfile('src/menu.lua'))()
local count=0
local function rendered_text(m,label)local found;for _,c in ipairs(m.compose(1920,1080))do if c.type=='text'and c.text==label then found=c end end;assert(found,'Missing rendered text: '..label);return found end
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));count=count+1;print('PASS '..name)end
local function spec(id)
 return {id=id or 'demo',name=id or 'Demo',pages={{id='general',name='General',controls={
  {id='toggle',type='toggle',label='Enabled',default=true},
  {id='slider',type='slider',label='Strength',min=0,max=10,step=.5,default=5},
  {id='choice',type='choice',label='Style',choices={'A','B','C'},default=1},
  {id='key',type='keybind',label='Key',default=0}}}}}
end
test('all 100 registered mods remain accessible in a sorted list',function()
 local api=core.new();for i=100,1,-1 do api.register(spec(string.format('mod_%03d',i)))end
 local list=api.list();assert(#list==100 and list[1].id=='mod_001' and list[100].id=='mod_100')
end)
test('invalid registration does not partly publish',function()
 local api=core.new();local s=spec();s.pages[1].controls[2].step=0
 assert(not pcall(api.register,s));assert(#api.list()==0)
end)
test('duplicate and unsafe IDs rejected',function()
 local api=core.new();api.register(spec());assert(not pcall(api.register,spec()));assert(not pcall(api.register,spec('../bad')))
 local s=spec('other');s.pages[1].controls[2].id='toggle';assert(not pcall(api.register,s))
end)
test('invalid persisted values fall back to reviewed defaults',function()
 local api=core.new({load=function()return {toggle=5,slider=100,choice=99,key=-1}end,save=function()return true end})
 local h=api.register(spec());assert(h.get('toggle')==true and h.get('slider')==5 and h.get('choice')==1 and h.get('key')==0)
end)
test('slider snapping and nonfinite range rejection',function()
 local h=core.new().register(spec());h.set('slider',5.26);assert(h.get('slider')==5.5)
 assert(not pcall(h.set,'slider',11));assert(not pcall(h.set,'slider',0/0));assert(not pcall(h.set,'choice',1.5))
end)
test('failed save does not commit or notify',function()
 local called=false;local s=spec();s.on_change=function()called=true end
 local api=core.new({load=function()return {}end,save=function()return false,'disk failure'end})
 local h=api.register(s);local ok,err=h.set('toggle',false);assert(not ok and err=='disk failure' and h.get('toggle') and not called)
end)
test('callbacks are isolated after successful persistence',function()
 local logs={};local s=spec();s.pages[1].controls[1].on_change=function()error('intentional failure')end
 local notified=false;s.on_change=function(v,k,old)notified=v==false and k=='toggle' and old==true end
 local h=core.new(nil,function(v)logs[#logs+1]=v end).register(s)
 assert(h.set('toggle',false));assert(notified and h.get('toggle')==false)
 local failures=0;for _,message in ipairs(logs)do if message:find('Callback failed',1,true)then failures=failures+1 end end;assert(failures==1)
end)
test('reset, late registration, unregister and replacement lifecycle',function()
 local api=core.new();local h=api.register(spec());h.set('slider',8);h.reset('slider');assert(h.get('slider')==5)
 h.unregister();assert(#api.list()==0);api.register(spec());assert(not pcall(h.set,'slider',2))
end)
test('button actions are not persisted and disabled controls do not change',function()
 local s=spec();local n=0;s.pages[1].controls[1].disabled=true
 s.pages[1].controls[#s.pages[1].controls+1]={id='run',type='button',label='Run',on_activate=function()n=n+1 end}
 local h=core.new().register(s);assert(not pcall(h.set,'toggle',false));assert(h.activate('run'));assert(n==1)
end)
test('F10 edge opens once and held key does not close immediately',function()
 local api=core.new();api.register(spec());local menu=menu_module.new(api)
 local down=true;local input={down=function(k)return k==121 and down end}
 menu.tick(input);assert(menu.visible);menu.tick(input);assert(menu.visible)
 down=false;menu.tick(input);down=true;menu.tick(input);assert(not menu.visible)
end)
test('keyboard navigation reaches mods beyond the eighth and their pages',function()
 local api=core.new();for i=1,20 do local s=spec(string.format('mod_%02d',i));s.pages[2]={id='extra',name='Extra',controls={}};api.register(s)end
 local m=menu_module.new(api);m.key(121);for i=1,19 do m.key(40)end;assert(m.selected==20)
 m.key(34);assert(m.page==2);local c=m.compose(1920,1080);assert(#c>0 and m.mod_scroll>0)
end)
test('keyboard edits selected settings, defaults and key capture',function()
 -- This case exercises immediate edits; default pages now stage until Apply.
 local api=core.new();local definition=spec();definition.pages[1].require_confirmation=false
 local h=api.register(definition);local m=menu_module.new(api);m.key(121);m.key(9);m.key(13)
 assert(h.get('toggle')==false);m.key(36);assert(h.get('toggle')==true)
 m.key(40);m.key(39);assert(h.get('slider')==5.5)
 m.key(40);m.key(40);m.key(13);m.key(65);assert(h.get('key')==65 and not m.capture)
 m.key(13);m.key(27);assert(h.get('key')==65 and m.visible)
end)
test('settings survive a fresh registry without executing data',function()
 local store=assert(loadfile('src/store.lua'))().new('tests/tmp');local h=core.new(store).register(spec('persist'))
 assert(h.set('slider',8.5));assert(h.set('toggle',false));local restored=core.new(store).register(spec('persist'))
 assert(restored.get('slider')==8.5 and restored.get('toggle')==false)
 os.remove('tests/tmp/persist.ini');os.remove('tests/tmp/persist.ini.bak')
end)
test('native GUI mock draws and cleans up without replacing global update',function()
 local draws,destroyed=0,0;local world={};local sr={Application={worlds=function()return {world}end,main_world=function()return world end},
  World={create_screen_gui=function()return {}end,destroy_gui=function()destroyed=destroyed+1 end},
  Vector2=function(...)return {...}end,Vector3=function(...)return {...}end,Color=function(...)return {...}end,
  Gui={rect=function()draws=draws+1;return draws end,text=function()draws=draws+1;return draws end,destroy_rect=function()end,destroy_text=function()end}}
 local api=core.new();api.register(spec());local m=menu_module.new(api);m.key(121)
 local v=assert(loadfile('src/view.lua'))().new(sr);v.draw(m.compose(1920,1080));assert(draws>10);v.draw({});assert(destroyed==1)
end)
test('capture restores exact cursor settings on close and focus loss',function()
 local capture_module=assert(loadfile('src/capture.lua'))();local values={focus=true,cursor=false,clip=false};local n={active=0}
 function n.mcm_install()return 1 end;function n.mcm_capture(v)n.active=v;return 1 end
 function n.mcm_captured()return n.active end;function n.mcm_release()n.active=0 end
 local w={};for _,k in ipairs({'focus','cursor','clip'})do
  local key=k;local getter=({focus='mouse_focus',cursor='show_cursor',clip='clip_cursor'})[key]
  w[getter]=function()return values[key]end;w['set_'..getter]=function(v)values[key]=v end
 end
 local c=capture_module.new(n,w,function()end);assert(c.sync(true,true,{}))
 assert(c.active and not values.focus and values.cursor and values.clip)
 assert(c.sync(false,true,{}));assert(not c.active and values.focus and not values.cursor and not values.clip and n.active==0)
 assert(c.sync(true,true,{}));assert(c.sync(true,false,{}));assert(not c.active and values.focus and not values.cursor)
end)
test('failed native capture restores cursor state and does not retain ownership',function()
 local capture_module=assert(loadfile('src/capture.lua'))();local values={focus=false,cursor=true,clip=true}
 local n={mcm_install=function()return 1 end,mcm_capture=function()return 0 end,mcm_release=function()end}
 local w={};for _,k in ipairs({'focus','cursor','clip'})do local key=k;local name=({focus='mouse_focus',cursor='show_cursor',clip='clip_cursor'})[key]
  w[name]=function()return values[key]end;w['set_'..name]=function(v)values[key]=v end end
 local c=capture_module.new(n,w,function()end);local ok=c.sync(true,true,{});assert(not ok and not c.active and not values.focus and values.cursor and values.clip)
end)
test('capture loss closes ownership and repeated release is safe',function()
 local capture_module=assert(loadfile('src/capture.lua'))();local calls=0
 local n={mcm_install=function()return 1 end,mcm_capture=function()return 1 end,mcm_captured=function()return 0 end,mcm_release=function()calls=calls+1 end}
 local w={mouse_focus=function()return true end,show_cursor=function()return false end,clip_cursor=function()return true end,
  set_mouse_focus=function()end,set_show_cursor=function()end,set_clip_cursor=function()end}
 local c=capture_module.new(n,w,function()end);assert(c.sync(true,true,{}));assert(not c.sync(true,true,{}));assert(not c.active)
 c.release();c.release();assert(calls==3)
end)
test('legacy bridge imports existing and late mods beyond eight and applies callbacks',function()
 local core=assert(loadfile('src/core.lua'))();local bridge=assert(loadfile('src/legacy.lua'))()
 local state={mods={},options={},callbacks={},revision=0};local values={};local host={api=1}
 function host.register_option(id,spec)state.options[id]=spec;return true end
 function host.get(id)return values[id]end
 function host.set(id,v)values[id]=v;return true end
 for i=1,10 do local id='old.'..i;state.mods['Mod '..i]={order={{id=id,kind='toggle',label='Enabled',default=false}}};values[id]=false end
 local api=core.new(nil,function()end);local b=bridge.new(api,function()end,core);b.poll(host);assert(#api.list()==10)
 local mod=api.list()[1];local called=0;local oldid=state.mods[mod.name].order[1].id
 state.callbacks[oldid]={function(v,id)assert(v and id==oldid);called=called+1 end}
 assert(mod.handle.set('option_1',true));assert(values[oldid] and called==1)
 assert(mod.handle.set('option_1',true));assert(called==1)
 state.mods.Late={order={{id='late',kind='slider',label='Amount',min=0,max=10,step=1,default=3}}};values.late=3;state.revision=1
 b.poll(host);assert(#api.list()==11);b.poll(nil);assert(#api.list()==0)
end)
test('wheel scrolls settings without selecting or changing them and clamps at ends',function()
 local core=assert(loadfile('src/core.lua'))();local menu_module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 local rows={};for i=1,30 do rows[i]={id='r'..i,type='toggle',label='Row '..i,default=false}end
 api.register({id='wheel',name='Wheel',pages={{id='p',name='Page',controls=rows}}})
 local m=menu_module.new(api);m.visible=true;m.compose(1920,1080)
 m.wheel(-120,1000,500);assert(m.scroll==3 and m.row==1);m.compose(1920,1080);assert(m.scroll==3)
 m.wheel(-12000,1000,500);assert(m.scroll==18);m.wheel(12000,1000,500);assert(m.scroll==0)
 m.wheel(-60,1000,500);assert(m.scroll==0);m.wheel(-60,1000,500);assert(m.scroll==3)
 m.wheel(-120,0,0);assert(m.scroll==3);assert(not api.get('wheel','r1'))
end)
test('slider drag previews snaps clamps and commits once on release',function()
 local core=assert(loadfile('src/core.lua'))();local menu_module=assert(loadfile('src/menu.lua'))();local writes=0
 local api=core.new({load=function()return {}end,save=function()writes=writes+1;return true end},function()end)
 api.register({id='drag',name='Drag',pages={{id='p',name='Page',require_confirmation=false,controls={{id='v',type='slider',label='Slider',min=0,max=100,step=5,default=0}}}}})
 local m=menu_module.new(api);m.visible=true;local track
 for _,c in ipairs(m.compose(1920,1080))do if c.type=='rect'and c.c[1]==31 and c.c[2]==76 and c.c[3]==84 and c.h<10 then track=c end end
 assert(track,'Slider track missing')
 local down=true;local px=track.x;local input={down=function(k)return k==1 and down end,mouse=function()return px,track.y end}
 m.tick(input);assert(writes==0);px=track.x+track.w;m.tick(input);assert(writes==0)
 down=false;m.tick(input);assert(api.get('drag','v')==100 and writes==1)
 m.compose(1920,1080);down=true;px=track.x;m.tick(input);m.key(121);down=false;m.tick(input);assert(writes==1)
end)
test('left arrow cannot open the closed menu; physical F10 still opens it',function()
 local core=assert(loadfile('src/core.lua'))();local menu_module=assert(loadfile('src/menu.lua'))()
 local m=menu_module.new(core.new(nil,function()end));m.key(37);assert(not m.visible)
 m.tick({down=function(k)return k==37 end});assert(not m.visible)
 m.tick({down=function(k)return k==121 end});assert(m.visible)
 local f=assert(io.open('src/adapter.lua'));local source=f:read('*a');f:close();assert(not source:find("binding_host.is_down",1,true))
end)
test('scrollbar thumb indicates top and bottom and is absent for short lists',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 local rows={};for i=1,40 do rows[i]={type='text',label='Row '..i}end
 api.register({id='scrollbar',name='Scrollbar',pages={{id='p',name='Page',controls=rows}}})
 local m=module.new(api);m.visible=true
 local function thumb(commands)for _,c in ipairs(commands)do if c.scrollbar=='settings' then return c end end end
 local top=assert(thumb(m.compose(1920,1080)));m.wheel(-12000,1000,500)
 local bottom=assert(thumb(m.compose(1920,1080)));assert(top.y>bottom.y and top.h==bottom.h and top.h>0)
 api.mods.scrollbar.pages[1].controls={{type='text',label='Short'}};assert(not thumb(m.compose(1920,1080)))
end)
test('confirmation page stages settings and actions and persists before callbacks',function()
 local core=assert(loadfile('src/core.lua'))();local writes,called,actions=0,0,0;local fail=true
 local api=core.new({load=function()return {}end,save=function()writes=writes+1;if fail then return false,'disk failure'end;return true end},function()end)
 local h=api.register({id='confirm',name='Confirm',pages={{id='sensitive',name='Sensitive',require_confirmation=true,controls={
 {id='a',type='toggle',label='A',default=false,on_change=function()called=called+1 end},
 {id='b',type='slider',label='B',min=0,max=10,step=1,default=0},
 {id='action',type='button',label='Action',require_confirmation=true,on_activate=function()actions=actions+1 end}}}}})
 h.edit('a',true);h.edit('b',5);h.queue('action');assert(h.preview('a') and not h.get('a') and writes==0 and called==0 and actions==0)
 assert(not h.confirm('sensitive'));assert(not h.get('a') and h.preview('b')==5 and called==0 and actions==0)
 fail=false;assert(h.confirm('sensitive'));assert(h.get('a') and h.get('b')==5 and called==1 and actions==1 and writes==2)
 h.edit('b',8);h.queue('action');h.discard('sensitive');assert(h.preview('b')==5 and actions==1)
end)
test('title drag moves all menu content and clamps at screen edges',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local m=module.new(core.new(nil,function()end))
 m.visible=true;m.compose(1920,1080);local px,py,down=600,920,true
 local input={down=function(k)return k==1 and down end,mouse=function()return px,py end}
 m.tick(input);px=700;py=970;m.tick(input);m.compose(1920,1080);assert(m.window_x==310 and m.window_y==180)
 px=9999;py=9999;m.tick(input);local commands=m.compose(1920,1080);assert(m.window_x==420 and m.window_y==260 and commands[1].x==420)
 down=false;m.tick(input);px=0;py=0;m.tick(input);assert(m.window_x==420)
 m.compose(1280,720);assert(m.window_x<=280 and m.window_y<=174)
end)
test('long dropdown scrolls independently selects once and Escape cancels',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 local choices={};for i=1,37 do choices[i]='Weapon '..i end
 api.register({id='dropdown',name='Dropdown',pages={{id='p',name='Page',require_confirmation=false,controls={{id='v',type='choice',label='Weapon',choices=choices,default=1}}}}})
 local m=module.new(api);m.visible=true;m.compose(1920,1080)
 local value=rendered_text(m,'Weapon 1');local down=true;local input={down=function(k)return k==1 and down end,mouse=function()return value.x,value.y end}
 m.tick(input);assert(m.dropdown);local commands=m.compose(1920,1080);local thumb=false
 for _,c in ipairs(commands)do if c.scrollbar=='dropdown'then thumb=true end end;assert(thumb)
 m.wheel(-12000,900,500);assert(m.dropdown.scroll==29 and m.scroll==0 and api.get('dropdown','v')==1)
 m.key(34);assert(m.dropdown.selected==9);m.key(13);assert(api.get('dropdown','v')==9 and not m.dropdown)
 down=false;m.tick(input);m.compose(1920,1080);down=true;m.tick(input);assert(m.dropdown)
 m.key(40);m.key(27);assert(not m.dropdown and api.get('dropdown','v')==9 and m.visible)
end)
test('popup primitives render above underlying text and choice arrows remain usable',function()
 local view=assert(loadfile('src/view.lua'))();local zs={};local world={}
 local sr={Application={worlds=function()return {world}end,main_world=function()return world end},World={create_screen_gui=function()return {}end,destroy_gui=function()end},
 Vector2=function(...)return {...}end,Vector3=function(...)return {...}end,Color=function(...)return {...}end,
 Gui={rect=function(_,p)zs[#zs+1]=p[3];return #zs end,text=function(_,_,_,_,_,p)zs[#zs+1]=p[3];return #zs end,destroy_rect=function()end,destroy_text=function()end}}
 view.new(sr).draw({{type='text',x=0,y=0,text='behind',size=18,c={255,255,255},a=1},{type='rect',x=0,y=0,w=10,h=10,c={0,0,0},a=1,layer=200},{type='text',x=0,y=0,text='popup',size=18,c={255,255,255},a=1,layer=200}})
 assert(zs[2]>zs[1] and zs[3]>zs[2])
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 api.register({id='arrows',name='Arrows',pages={{id='p',name='Page',require_confirmation=false,controls={{id='v',type='choice',label='Choice',choices={'A','B'},default=1}}}}})
 local m=module.new(api);m.visible=true;local arrow=rendered_text(m,'>');m.tick({down=function(k)return k==1 end,mouse=function()return arrow.x,arrow.y end})
 assert(api.get('arrows','v')==2 and not m.dropdown)
end)
test('text entry commits when clicking away without Enter',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 api.register({id='entry',name='Entry',pages={{id='p',name='Page',require_confirmation=false,controls={{id='name',type='input',label='Name',default='Old'}}}}})
 local m=module.new(api);m.visible=true;m.compose(1920,1080)
 m.text_edit={mod=api.list()[1],control=api.list()[1].pages[1].controls[1],text='Goose',replace=false}
 m.tick({down=function(k)return k==1 end,mouse=function()return 1900,1000 end})
 assert(api.get('entry','name')=='Goose' and not m.text_edit)
end)

test('numeric value entry commits snapped values rejects range errors and cancels',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 api.register({id='entry',name='Entry',pages={{id='p',name='Page',require_confirmation=false,controls={{id='v',type='slider',label='Value',min=-10,max=10,step=.5,default=0}}}}})
 local m=module.new(api);m.visible=true;m.compose(1920,1080)
 local value=rendered_text(m,'0');local down=true;local input={down=function(k)return k==1 and down end,mouse=function()return value.x,value.y end}
 m.tick(input);assert(m.text_edit);m.key(189);m.key(50);m.key(190);m.key(51);m.key(13);assert(api.get('entry','v')==-2.5 and not m.text_edit)
 down=false;m.tick(input);m.compose(1920,1080);down=true;m.tick(input);m.key(57);m.key(57);m.key(13);assert(m.text_edit and api.get('entry','v')==-2.5 and m.visible)
 m.key(27);assert(not m.text_edit and m.visible)
end)
test('categories support nested pages flat compatibility and reject cycles',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 local spec={id='hierarchy',name='Hierarchy',categories={{id='hud',name='HUD'},{id='advanced',name='Advanced',parent='hud'}},pages={
 {id='colors',name='Colors',category='hud',controls={}},{id='location',name='Location',category='hud',controls={}},{id='misc',name='Misc',category='advanced',controls={}}}}
 api.register(spec);local m=module.new(api);local rows=m.navigation(api.mods.hierarchy)
 assert(#rows==5 and rows[1].category.id=='hud' and rows[2].depth==1 and rows[3].depth==2)
 local bad=core.new(nil,function()end);spec.categories[1].parent='advanced';assert(not pcall(bad.register,spec));assert(not bad.mods.hierarchy)
 local flat=core.new(nil,function()end);flat.register({id='flat',name='Flat',pages={{id='p',name='Page',controls={}}}})
 assert(module.new(flat).navigation(flat.mods.flat)[1].kind=='page')
end)
test('HUD compatibility nesting retains original setting routes and callbacks',function()
 local core=assert(loadfile('src/core.lua'))();local bridge=assert(loadfile('src/legacy.lua'))();local menu=assert(loadfile('src/menu.lua'))()
 local state={mods={},options={},callbacks={},revision=0};local values={};local host={api=1}
 function host.register_option(id,spec)state.options[id]=spec;return true end
 function host.get(id)return values[id]end
 function host.set(id,v)values[id]=v;return true end
 for i,name in ipairs({'DBF-HUD','DBF-HUD LAYOUT EDITOR','DBF-HUD PLACEMENT'})do local id='original.'..i
 state.mods[name]={order={{id=id,kind='toggle',label='Toggle',default=false}}};values[id]=false end
 local called=0;state.callbacks['original.2']={function()called=called+1 end}
 local api=core.new(nil,function()end);local importer=bridge.new(api,function()end,core);importer.poll(host)
 assert(#api.list()==1);local root=api.list()[1];assert(root.name=='DBF-HUD' and #root.pages==3 and #root.categories==1)
 assert(root.handle.edit('layout_editor_option_1',true));assert(not values['original.2'] and called==0)
 assert(root.handle.confirm('layout_editor_settings'));assert(values['original.2'] and called==1 and not values['original.1'])
 local nodes=menu.new(api).navigation(root);assert(#nodes==4 and nodes[1].category.name=='HUD')
 assert(nodes[2].page.name=='Layout' and nodes[3].page.name=='Placement' and nodes[4].page.name=='General')
 local color
 api.register({id='dbf_hud_fonts',name='DBF-HUD Appearance',pages={{id='appearance',name='Appearance',require_confirmation=false,controls={{id='color',type='color',label='Decorations',default='#FFFFFF',on_change=function(v)color=v end}}}}})
 importer.poll(host);assert(#api.list()==1)
 root=api.list()[1];assert(#root.pages==3 and root.pages[3].name=='Appearance')
 assert(root.handle.edit('appearance_color','#123456'));assert(color=='#123456')
 api.mods.dbf_hud_fonts.handle.unregister();importer.poll(host);assert(#api.list()==1 and #api.list()[1].pages==3)

end)
test('mod tree expands children directly beneath the parent in one sidebar',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 api.register({id='hud',name='DBF-HUD',categories={{id='hud',name='HUD'}},pages={{id='layout',name='Layout',category='hud',controls={}},{id='placement',name='Placement',category='hud',controls={}},{id='general',name='General',category='hud',controls={}}}})
 api.register({id='other',name='Other',pages={{id='p',name='Page',controls={}}}})
 local m=module.new(api);m.visible=true;m.compose(1920,1080);local down=true
 local input={down=function(k)return k==1 and down end,mouse=function()return 300,801 end};m.tick(input)
 local tree=m.sidebar();assert(#tree==5 and tree[1].mod.name=='DBF-HUD' and tree[2].page.name=='Layout' and tree[3].page.name=='Placement' and tree[4].page.name=='General' and tree[5].mod.name=='Other')
 assert(tree[2].depth==1);m.compose(1920,1080);down=false;m.tick(input);down=true;m.tick(input);assert(#m.sidebar()==2)
end)
test('last tree child stem ends exactly at its horizontal junction',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 api.register({id='a',name='A',pages={{id='one',name='One',controls={}},{id='two',name='Two',controls={}}}})
 api.register({id='b',name='B',pages={{id='p',name='Page',controls={}}}})
 local m=module.new(api);m.visible=true;m.compose(1920,1080);m.tick({down=function(k)return k==1 end,mouse=function()return 300,801 end})
 local stems={};for _,c in ipairs(m.compose(1920,1080))do if c.tree_branch then stems[#stems+1]=c end end
 assert(#stems==2 and not stems[1].tree_branch.last and stems[2].tree_branch.last)
 assert(stems[2].y==stems[2].tree_branch.junction and stems[2].h==18)
end)
test('colors accept RGB and HEX persist canonically and reject invalid channels',function()
 local core=assert(loadfile('src/core.lua'))();local store_module=assert(loadfile('src/store.lua'))();local store=store_module.new('tests/tmp')
 local api=core.new(store,function()end);local h=api.register({id='color_test',name='Color',pages={{id='p',name='Page',require_confirmation=true,controls={{id='v',type='color',label='Color',default='#000000'}}}}})
 assert(h.set('v',{r=255,g=128,b=0}));assert(h.get('v')=='#FF8000');assert(store.load('color_test').v=='#FF8000')
 h.edit('v','00ffcc');assert(h.preview('v')=='#00FFCC' and h.get('v')=='#FF8000');assert(h.confirm('p'));assert(h.get('v')=='#00FFCC')
 assert(not pcall(h.set,'v',{256,0,0}));assert(not pcall(h.set,'v','#ZZ0000'));assert(core.color_rgb('#00FFCC')[2]==255)
end)
test('color dialog uses a higher bounded depth than the main menu',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 api.register({id='color_depth',name='Color Depth',pages={{id='p',name='Page',controls={{id='v',type='color',label='Color',default='#FF0000'}}}}})
 local m=module.new(api);m.visible=true;local value=rendered_text(m,'#FF0000');m.tick({down=function(k)return k==1 end,mouse=function()return value.x,value.y end})
 assert(m.color_picker);local popup=0
 for index,c in ipairs(m.compose(1920,1080))do local z=(c.layer or 100)+index*.01;assert(z<512)
  if c.layer==300 then popup=popup+1;assert(z>200)end
 end
 assert(popup>10)
end)
test('color dialog body clicks stay open and its title bar drags independently',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 api.register({id='color_move',name='Color Move',pages={{id='p',name='Page',controls={{id='v',type='color',label='Color',default='#FF0000'}}}}})
 local m=module.new(api);m.visible=true;local value=rendered_text(m,'#FF0000');local down=true;local px,py=value.x,value.y
 local input={down=function(k)return k==1 and down end,mouse=function()return px,py end}
 m.tick(input);m.compose(1920,1080);down=false;m.tick(input);px=1090;py=450;down=true;m.tick(input);assert(m.color_picker)
 down=false;m.tick(input);px=800;py=730;down=true;m.tick(input);px=900;py=780;m.tick(input)
 assert(m.color_picker.x==500 and m.color_picker.y==245 and m.window_x==210)
end)
test('color fields update on blur and Use Color includes the unsubmitted field',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 api.register({id='blur',name='Blur',pages={{id='p',name='Page',require_confirmation=false,controls={{id='v',type='color',label='Color',default='#000000'}}}}})
 local m=module.new(api);m.visible=true;m.color_picker={mod=api.mods.blur,control=api.mods.blur.controls.v,rgb={0,0,0}}
 m.text_edit={color_channel=1,text='128'};m.compose(1920,1080)
 m.tick({down=function(k)return k==1 end,mouse=function()return 1010,626 end})
 assert(m.color_picker.rgb[1]==128 and m.text_edit.color_channel==2)
 m.text_edit={color_channel='hex',text='aabbcc'};m.commit_color();assert(api.get('blur','v')=='#AABBCC' and not m.color_picker)
 m.color_picker={mod=api.mods.blur,control=api.mods.blur.controls.v,rgb={0,0,0}};m.text_edit={color_channel=1,text='999'}
 assert(not m.finish_color_field());assert(m.text_edit and m.color_picker.rgb[1]==0)
end)
test('custom swatches persist normalize deduplicate and retain twelve newest colors',function()
 local core=assert(loadfile('src/core.lua'))();local saved={};local fail=false
 local store={load=function(id)return saved[id] or {}end,save=function(id,v)if fail then return false,'disk error'end;saved[id]=v;return true end}
 local api=core.new(store,function()end);assert(api.save_swatch({255,0,0}));assert(api.save_swatch('ff0000'));assert(#api.swatches()==1)
 local fresh=core.new(store,function()end);assert(fresh.swatches()[1]=='#FF0000')
 fail=true;assert(not fresh.save_swatch('#00FF00'));assert(#fresh.swatches()==1);fail=false
 for i=1,15 do fresh.save_swatch(string.format('#0000%02X',i))end
 assert(#fresh.swatches()==12 and fresh.swatches()[12]=='#00000F')
 assert(core.hsv_rgb(0,1,1)[1]==255);local h,s,v=core.rgb_hsv({0,255,0});assert(math.abs(h-1/3)<.001 and s==1 and v==1)
end)
test('selected swatch replacement keeps position persists and survives write failure',function()
 local core=assert(loadfile('src/core.lua'))();local saved={};local fail=false
 local store={load=function(id)return saved[id] or {}end,save=function(id,v)if fail then return false,'disk error'end;saved[id]=v;return true end}
 local api=core.new(store,function()end);api.save_swatch('#FF0000');api.save_swatch('#00FF00')
 assert(api.replace_swatch(1,{0,0,255}));assert(#api.swatches()==2 and api.swatches()[1]=='#0000FF' and api.swatches()[2]=='#00FF00')
 assert(core.new(store,function()end).swatches()[1]=='#0000FF')
 fail=true;assert(not api.replace_swatch(1,'#FFFFFF'));assert(api.swatches()[1]=='#0000FF')
 assert(not pcall(api.replace_swatch,3,'#FFFFFF'))
end)
test('window close buttons close only their own window',function()
 local core=assert(loadfile('src/core.lua'))();local module=assert(loadfile('src/menu.lua'))();local api=core.new(nil,function()end)
 local m=module.new(api);m.visible=true;m.color_picker={rgb={255,0,0}};m.compose(1920,1080)
 local down=true;local px,py=1275,730;local input={down=function(k)return k==1 and down end,mouse=function()return px,py end}
 m.tick(input);assert(not m.color_picker and m.visible)
 down=false;m.tick(input);m.compose(1920,1080);px=1670;py=920;down=true;m.tick(input);assert(not m.visible)
end)
test('compatibility API works without original menu and preserves callback semantics',function()
 local compat=assert(loadfile('src/compat.lua'))();local core=assert(loadfile('src/core.lua'))();local legacy=assert(loadfile('src/legacy.lua'))()
 local saved={};local store={load=function()return saved end,save=function(_,v)saved=v;return true end}
 local host=compat.new(store);local calls=0
 assert(host.api==1 and host.ready())
 assert(host.register_option('example.enabled',{type='toggle',mod='Example',label='Enabled',default=false}))
 assert(host.register_option('example.rate',{type='slider',mod='Example',label='Rate',min=0,max=10,step=2,default=4}))
 assert(host.register_option('example.mode',{type='choice',mod='Example',label=function()return 'Mode' end,choices={'A','B'},default=1}))
 assert(host.on_change('example.enabled',function(v,id)assert(type(v)=='boolean' and id=='example.enabled');calls=calls+1 end))
 assert(host.set('example.enabled',true) and calls==0)
 assert(host.set('example.rate',5) and host.get('example.rate')==6)
 assert(not host.set('example.mode',3))
 assert(not host.register_option('example.rate',{type='toggle',label='Different'}))
 local api=core.new(nil,function()end);local importer=legacy.new(api,function()end,core);importer.poll(host)
 local mod=api.list()[1];assert(mod and #mod.pages[1].controls==3)
 local id;for _,c in ipairs(mod.pages[1].controls)do if c.label=='Enabled'then id=c.id end end
 assert(mod.handle.set(id,false));calls=0;assert(mod.handle.set(id,true) and calls==1)
 local restored=compat.new(store);assert(restored.register_option('example.enabled',{type='toggle',label='Enabled'}));assert(restored.get('example.enabled'))
end)
test('moving retained menu primitives destroys stale IDs before replacements',function()
 local module=assert(loadfile('src/view.lua'))();local world={};local living={};local next_id=0;local started=false
 local sr={Application={worlds=function()return {world}end,main_world=function()return world end},World={create_screen_gui=function()return {}end,destroy_gui=function()end},Vector2=function(...)return {...}end,Vector3=function(...)return {...}end,Color=function(...)return {...}end,Gui={}}
 local free={};local function draw()started=true;local id=table.remove(free);if not id then next_id=next_id+1;id=next_id end;living[id]=true;return id end
 local function destroy(_,id)assert(not started,'Stale destroy followed an allocation');living[id]=nil;free[#free+1]=id end
 sr.Gui.rect=draw;sr.Gui.text=draw;sr.Gui.destroy_rect=destroy;sr.Gui.destroy_text=destroy
 local v=module.new(sr);local commands={{type='rect',x=0,y=0,w=10,h=10,c={0,0,0},a=1},{type='text',x=0,y=0,text='Label',size=18,c={255,255,255},a=1}}
 v.draw(commands);started=false;commands[1].x=20;commands[2].x=20;v.draw(commands)
 local n=0;for _ in pairs(living)do n=n+1 end;assert(n==2)
end)
test('compatibility registrations and callbacks survive menu reload',function()
 local compat=assert(loadfile('src/compat.lua'))();local old,state=compat.new(nil);local called=0
 assert(old.register_option('shallow.depth',{type='slider',mod='Shallow water diving',label='Depth',min=0,max=10,default=4}))
 old.on_change('shallow.depth',function()called=called+1 end)
 local replacement=compat.new(nil,state);assert(replacement.get('shallow.depth')==4)
 assert(old.set('shallow.depth',6) and replacement.get('shallow.depth')==6)
 local core=assert(loadfile('src/core.lua'))();local api=core.new(nil,function()end)
 local importer=assert(loadfile('src/legacy.lua'))().new(api,function()end,core);importer.poll(replacement)
 local mod=api.list()[1];assert(mod and mod.name=='SHALLOW WATER DIVING')
 assert(mod.handle.set(mod.pages[1].controls[1].id,8));assert(called==1 and old.get('shallow.depth')==8)
end)
assert(loadfile('src/adapter.lua'));assert(loadfile('dist/dbf_mcm/mod.lua'))
print(count..' meaningful contract tests passed; native rendering/input remain unverified')
