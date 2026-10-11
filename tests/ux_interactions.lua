-- Context-sensitive acceptance and real pointer context menus; isolated state only.
local Core=dofile('src/core.lua')
local Menu=dofile('src/menu.lua')
local Preferences=dofile('src/preferences.lua')
local passed=0
local function test(name,fn)local ok,why=pcall(fn);assert(ok,name..': '..tostring(why));passed=passed+1;print('PASS '..name)end
local function setup()
    local counts={writes=0,changes=0,actions=0};local refuse=false
    local api=Core.new({load=function()return{}end,save=function()if refuse then return false,'disk unavailable'end;counts.writes=counts.writes+1;return true end})
    local h=api.register({id='demo',name='Demo',pages={{id='general',name='General',require_confirmation=true,controls={
        {id='enabled',type='toggle',label='Enabled',default=false,on_change=function()counts.changes=counts.changes+1 end},
        {id='name',type='input',label='Name',default='Original'},
        {id='amount',type='slider',label='Amount',min=0,max=10,step=1,default=5},
        {id='choice',type='choice',label='Choice',presentation='dropdown',choices={'One','Two','Three'},default=1},
        {id='accent',type='color',label='Accent',default='#FFFFFF'},
        {id='action',type='button',label='Action',button_label='RUN',require_confirmation=false,on_activate=function()counts.actions=counts.actions+1 end},
    }}}})
    local menu=Menu.new(api);menu.visible=true;menu.focus='settings';menu.compose(1920,1080)
    return{api=api,h=h,menu=menu,mod=api.mods.demo,page=api.mods.demo.pages[1],counts=counts,refuse=function(value)refuse=value end}
end
local function item(menu,label)
    for index,value in ipairs(assert(menu.context_menu).items)do if value.label==label then return index,value end end
    error('Missing context action '..label)
end
test('Tab accepts text then applies once while Shift Tab preserves pending values',function()
    local s=setup();s.menu.text_edit={mod=s.mod,control=s.mod.controls.name,text='Edited',replace=false}
    s.menu.key(9);assert(not s.menu.text_edit and s.h.preview('name')=='Edited'and s.h.get('name')=='Original'and s.counts.writes==0)
    local focus=s.menu.focus;s.menu.key(9,false,true)
    assert(s.menu.focus~=focus and s.h.get('name')=='Original'and s.counts.writes==0,'Shift Tab applied pending edits')
    s.menu.key(9);assert(s.h.get('name')=='Edited'and s.counts.writes==1,'Tab did not apply the pending page')
    s.menu.key(9);assert(s.counts.writes==1,'Idle Tab repeated persistence')
end)
test('Tab refuses invalid numeric input and preserves failed pending applies',function()
    local s=setup();s.menu.text_edit={mod=s.mod,control=s.mod.controls.amount,text='99',replace=false}
    s.menu.key(9);assert(s.menu.text_edit and s.h.get('amount')==5 and s.counts.writes==0)
    s.menu.key(27);assert(s.h.edit('enabled',true));s.refuse(true);s.menu.key(9)
    assert(s.h.preview('enabled')and not s.h.get('enabled')and s.counts.changes==0 and s.menu.notice=='disk unavailable')
    s.refuse(false);s.menu.key(9);assert(s.h.get('enabled')and s.counts.writes==1 and s.counts.changes==1)
end)
test('Tab accepts dropdown and color dialogs without premature persistence',function()
    local s=setup();s.menu.row=4;s.menu.key(13);assert(s.menu.dropdown)
    s.menu.key(40);s.menu.key(9);assert(not s.menu.dropdown and s.h.preview('choice')==2 and s.h.get('choice')==1)
    s.menu.color_picker={mod=s.mod,control=s.mod.controls.accent,rgb={255,255,255}}
    s.menu.text_edit={mod=s.mod,control=s.mod.controls.accent,color_channel=1,text='12',replace=false}
    s.menu.key(9);assert(not s.menu.text_edit and s.menu.color_picker.rgb[1]==12 and s.h.get('accent')=='#FFFFFF')
    s.menu.key(9);assert(not s.menu.color_picker and s.h.preview('accent')=='#0CFFFF'and s.counts.writes==0)
    s.menu.key(9);assert(s.h.get('choice')==2 and s.h.get('accent')=='#0CFFFF'and s.counts.writes==1)
end)
test('right click reaches the setting row through field hits and never edits on open',function()
    local s=setup();local px,py,down=0,0,false
    for _,command in ipairs(s.menu.compose(1920,1080))do if command.type=='text'and command.text=='OFF'then px,py=command.x+2,command.y+2 end end
    assert(px>0,'Toggle field missing')
    local input={down=function(key)return key==2 and down end,mouse=function()return px,py end}
    s.menu.tick(input);down=true;s.menu.tick(input)
    assert(s.menu.context_menu and s.menu.context_menu.title=='Enabled'and not s.h.preview('enabled')and s.counts.writes==0,'Right click toggled or failed to find its row')
    local toggle=item(s.menu,'Toggle setting');s.menu.context_menu.selected=toggle;s.menu.key(13)
    assert(not s.menu.context_menu and s.h.preview('enabled')and not s.h.get('enabled')and s.counts.writes==0)
end)
test('context reset uses staged defaults and page discard retains saved values',function()
    local s=setup();assert(s.h.edit('amount',8))
    local target={kind='control',mod=s.mod,page=s.page,control=s.mod.controls.amount,row=3}
    assert(s.menu.open_context(target,300,400));s.menu.run_context(item(s.menu,'Reset to default'))
    assert(s.h.preview('amount')==5 and s.h.get('amount')==5 and s.counts.writes==0)
    assert(s.h.edit('amount',9));s.menu.open_context(target,300,400);s.menu.run_context(item(s.menu,'Discard page changes'))
    assert(s.h.preview('amount')==5 and s.h.get('amount')==5 and s.counts.writes==0)
end)
test('context keyboard skips disabled items and Escape closes only the popup',function()
    local s=setup();s.mod.controls.action.disabled=true
    s.menu.open_context({kind='control',mod=s.mod,page=s.page,control=s.mod.controls.action,row=6},300,400)
    local index,entry=item(s.menu,'Run action');assert(not entry.enabled)
    s.menu.context_menu.selected=index;s.menu.key(9);assert(s.menu.context_menu and s.counts.actions==0)
    s.menu.key(27);assert(not s.menu.context_menu and s.menu.visible and s.counts.writes==0)
    s.menu.open_context({kind='page',mod=s.mod,page=s.page},300,400);s.menu.key(40)
    assert(s.menu.context_menu.items[s.menu.context_menu.selected].enabled)
end)
test('retired context owners cannot execute stale callbacks and focus loss clears popup',function()
    local s=setup();s.menu.open_context({kind='control',mod=s.mod,page=s.page,control=s.mod.controls.action,row=6},300,400)
    local index=item(s.menu,'Run action');s.h.unregister();assert(not s.menu.run_context(index)and s.counts.actions==0 and not s.menu.context_menu)
    local fresh=setup();fresh.menu.open_context({kind='mod',mod=fresh.mod},300,400)
    fresh.menu.input_focus(false,{down=function()return false end});assert(not fresh.menu.context_menu)
end)
test('verbose loader config is independent from UI values and changes only after explicit persistence',function()
    local s=setup();local config={verbose_registration=false};local writes=0;local fail=false
    assert(not Preferences.config_defaults().verbose_registration and not Preferences.verbose_registration(config))
    local context={set=function(key,value)writes=writes+1;if fail then return false,'config refused'end;config[key]=value;return true end}
    assert(Preferences.set_verbose(s.api,true,context)and s.api.get_verbose()and config.verbose_registration and writes==1 and s.counts.writes==0)
    fail=true;local ok,why=Preferences.set_verbose(s.api,false,context)
    assert(not ok and why=='config refused'and s.api.get_verbose()and config.verbose_registration)
    fail=false;assert(Preferences.set_verbose(s.api,false,context)and not s.api.get_verbose()and not config.verbose_registration)
    assert(s.h.get('amount')==5 and s.h.get('name')=='Original'and s.counts.writes==0)
end)
print('PASS '..passed..' acceptance, context menu and runtime config contracts')
