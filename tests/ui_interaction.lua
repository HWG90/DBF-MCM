-- UI contracts use only isolated state; no native capture or game input.
local Core=dofile('src/core.lua')
local Grouping=dofile('src/grouping.lua')
local Menu=dofile('src/menu.lua')
local passed=0
local function test(name,fn)
    fn();passed=passed+1;print('PASS '..name)
end
local function setting(id,extra)
    local c={id=id,type='toggle',label=id,default=false}
    for key,value in pairs(extra or {})do c[key]=value end
    return c
end
local function text_command(menu,label)
    for _,command in ipairs(menu.compose(1920,1080))do
        if command.type=='text' and (command.full_text or command.text)==label then return command end
    end
    error('Missing UI label: '..label)
end

test('mixed immediate and deferred edits persist before callbacks and retain failed edits',function()
    local saved,writes,callbacks={},0,{}
    local refuse=false
    local store={load=function()return {}end,save=function(id,values)
        writes=writes+1
        if refuse then return false,'disk unavailable' end
        saved[id]={};for key,value in pairs(values)do saved[id][key]=value end
        return true
    end}
    local function changed(value,id)
        assert(saved.mixed[id]==value,'callback ran before persistence')
        callbacks[#callbacks+1]=id
    end
    local api=Core.new(store)
    local handle=api.register({id='mixed',name='Mixed',pages={{id='p',name='Page',require_confirmation=true,controls={
        setting('instant',{require_confirmation=false,on_change=changed}),
        setting('deferred',{on_change=changed})
    }}}})
    local page=api.mods.mixed.pages[1]
    assert(handle.edit('instant',true))
    assert(handle.get('instant') and not page.pending.instant and writes==1 and #callbacks==1)
    assert(handle.edit('deferred',true))
    assert(not handle.get('deferred') and handle.preview('deferred') and page.pending.deferred==true)
    assert(writes==1 and #callbacks==1,'deferred edit was committed early')
    refuse=true
    local ok,reason=handle.edit('instant',false)
    assert(not ok and reason=='disk unavailable' and handle.get('instant') and #callbacks==1)
    assert(not page.pending.instant,'failed immediate edit became deferred')
    ok,reason=handle.confirm('p')
    assert(not ok and reason=='disk unavailable' and page.pending.deferred and not handle.get('deferred'))
    assert(#callbacks==1,'failed save fired a callback')
    refuse=false
    assert(handle.confirm('p') and handle.get('deferred') and next(page.pending)==nil)
    assert(#callbacks==2 and callbacks[2]=='deferred')
    assert(handle.edit('instant',false) and not handle.get('instant') and #callbacks==3)
end)

test('mounted immediate aliases use one authoritative value and retain preview presentation',function()
    local writes,changes=0,0
    local api=Core.new({load=function()return {}end,save=function()writes=writes+1;return true end},nil,Grouping)
    api.register({id='parent',name='Parent',pages={{id='overview',name='Overview',require_confirmation=true,preview_popout=true,controls={}}}})
    local child=api.register({id='child',name='Child',parent_name='Parent',pages={{id='p',name='Child page',require_confirmation=true,controls={
        setting('enabled',{require_confirmation=false,on_change=function()changes=changes+1 end})
    }}}})
    local page=api.mods.parent.pages[1]
    page.controls[#page.controls+1]={id='linked',type='toggle',label='Linked',require_confirmation=false,source_mod_id='child',source_control_id='enabled',groups={}}
    local composite=api.list()[1]
    assert(composite.pages[1].preview_popout,'mount lost preview_popout')
    assert(composite.handle.edit('linked',true))
    assert(child.get('enabled') and composite.handle.get('linked') and writes==1 and changes==1)
    assert(next(api.mods.child.pages[1].pending)==nil and api.mods.parent.values.linked==nil)
    assert(child.edit('enabled',false) and not composite.handle.preview('linked') and writes==2 and changes==2)
end)

test('linked binding notice follows authoritative pending state rather than presentation page',function()
    local writes=0
    local api=Core.new({load=function()return {}end,save=function()writes=writes+1;return true end},nil,Grouping)
    api.register({id='parent',name='Parent',pages={{id='quick',name='Quick',require_confirmation=false,controls={}}}})
    local child=api.register({id='child',name='Child',parent_name='Parent',pages={{id='p',name='Child page',require_confirmation=true,controls={
        {id='binding',type='keybind',label='Binding',default=46}
    }}}})
    api.mods.parent.pages[1].controls[1]={id='linked',type='keybind',label='Linked',source_mod_id='child',source_control_id='binding',groups={}}
    local menu=Menu.new(api);menu.visible=true;menu.focus='settings';menu.compose(1920,1080)
    menu.key(13);assert(menu.capture);menu.key(65)
    assert(child.get('binding')==46 and child.preview('binding')==65 and writes==0)
    assert(menu.notice=='Changes ready to apply','linked pending binding was reported saved')
    assert(api.mods.parent.values.linked==nil,'linked binding created a second authoritative value')
end)

test('Enter opens dropdown choices without committing until acceptance',function()
    local changes=0
    local api=Core.new()
    local handle=api.register({id='choices',name='Choices',pages={{id='p',name='Page',require_confirmation=false,controls={
        {id='list',type='choice',presentation='dropdown',label='Choice',choices={'Alpha','Beta','Gamma'},default=2,on_change=function()changes=changes+1 end},
        {id='selector',type='choice',presentation='selector',label='Selector',choices={'One','Two'},default=1}
    }}}})
    local menu=Menu.new(api);menu.visible=true;menu.focus='settings';menu.compose(1920,1080)
    menu.key(13)
    assert(menu.dropdown and menu.dropdown.selected==2 and handle.get('list')==2 and changes==0)
    menu.key(40);assert(menu.dropdown.selected==3 and handle.get('list')==2)
    menu.key(27);assert(not menu.dropdown and menu.visible and handle.get('list')==2 and changes==0)
    menu.key(13);menu.key(38);menu.key(13)
    assert(not menu.dropdown and handle.get('list')==1 and changes==1)
    menu.row=2;menu.key(13)
    assert(not menu.dropdown and handle.get('selector')==2,'selector-only presentation changed contract')
end)

test('pointer hover does not steal keyboard selection focus or write settings',function()
    local writes=0
    local api=Core.new({load=function()return {}end,save=function()writes=writes+1;return true end})
    local handle=api.register({id='hover',name='Hover',pages={{id='p',name='Page',require_confirmation=false,controls={
        setting('first',{label='First option'}),setting('second',{label='Second option'})
    }}}})
    local menu=Menu.new(api);menu.visible=true;menu.row=1;menu.focus='mods'
    local second=text_command(menu,'Second option')
    local px,py=second.x+4,second.y+4
    local input={down=function()return false end,mouse=function()return px,py end}
    menu.tick(input);menu.compose(1920,1080)
    assert(menu.pointer_x==px and menu.pointer_y==py,'pointer was not tracked for hover')
    assert(menu.row==1 and menu.focus=='mods' and not handle.get('first') and not handle.get('second') and writes==0)
    px,py=0,0;menu.tick(input);menu.compose(1920,1080)
    assert(menu.row==1 and menu.focus=='mods' and writes==0,'hover exit mutated interaction state')
end)

test('settings scrollbar thumb drag preserves grab position clamps and never edits values',function()
    local writes=0
    local api=Core.new({load=function()return {}end,save=function()writes=writes+1;return true end})
    local controls={};for index=1,40 do controls[#controls+1]=setting('row_'..index)end
    api.register({id='scroll',name='Scroll',pages={{id='p',name='Page',require_confirmation=false,controls=controls}}})
    local menu=Menu.new(api);menu.visible=true;menu.focus='settings';menu.row=1
    local thumb
    for _,command in ipairs(menu.compose(1920,1080))do if command.scrollbar=='settings' then thumb=command end end
    assert(thumb,'settings scrollbar thumb missing')
    local px,py=thumb.x+thumb.w/2,thumb.y+thumb.h/2
    local down=true
    local input={down=function(code)return code==1 and down end,mouse=function()return px,py end}
    menu.tick(input);assert(menu.scroll==0,'grabbing thumb jumped scroll position')
    py=menu.window_bounds.y-200;menu.tick(input);menu.compose(1920,1080)
    assert(menu.scroll==menu.display_total-menu.settings_visible,'drag did not clamp at last row')
    assert(menu.row==1 and menu.focus=='settings' and writes==0,'scrollbar drag edited or selected a setting')
    py=menu.window_bounds.y+menu.window_bounds.h+200;menu.tick(input);menu.compose(1920,1080)
    assert(menu.scroll==0,'drag did not clamp at first row')
    down=false;menu.tick(input);menu.compose(1920,1080)
    assert(menu.row==1 and writes==0)
end)

test('closing and reopening while holding scrollbar drag cannot resume stale movement',function()
    for _,close_key in ipairs({46,27})do
        local api=Core.new();local controls={}
        for index=1,40 do controls[#controls+1]=setting('row_'..index)end
        api.register({id='scroll',name='Scroll',pages={{id='p',name='Page',controls=controls}}})
        local menu=Menu.new(api);menu.visible=true
        local thumb
        for _,command in ipairs(menu.compose(1920,1080))do if command.scrollbar=='settings' then thumb=command end end
        assert(thumb)
        local px,py=thumb.x+thumb.w/2,thumb.y+thumb.h/2
        local down=true
        local input={down=function(code)return code==1 and down end,mouse=function()return px,py end}
        menu.tick(input);assert(menu.scroll==0)
        menu.key(close_key);assert(not menu.visible and #menu.compose(1920,1080)==0)
        menu.key(46);assert(menu.visible);menu.compose(1920,1080)
        py=menu.window_bounds.y-200;menu.tick(input);menu.compose(1920,1080)
        assert(menu.scroll==0,'closed scrollbar drag resumed after reopen via key '..close_key)
        down=false;menu.tick(input)
    end
end)

test('shell and hover row backgrounds stay behind retained fields and text',function()
    local api=Core.new()
    api.register({id='layers',name='Layers',pages={{id='p',name='Page',controls={
        setting('first',{label='First option'}),setting('second',{label='Second option'})
    }}}})
    local menu=Menu.new(api);menu.visible=true
    local function depth(command)return (command.layer or 100)+(command.type=='text' and 1 or 0)end
    local function verify(commands)
        local rows,fields,labels=0,0,0
        local maximum_row,minimum_field,minimum_text=-math.huge,math.huge,math.huge
        for _,command in ipairs(commands)do
            if command.ui_role=='setting_row' then rows=rows+1;maximum_row=math.max(maximum_row,depth(command))end
            if command.type=='rect' and command.w==175 and command.h==29 then fields=fields+1;minimum_field=math.min(minimum_field,depth(command))end
            if command.type=='text' and command.text=='OFF' then labels=labels+1;minimum_text=math.min(minimum_text,depth(command))end
        end
        assert(rows==2 and fields==2 and labels==2)
        assert(depth(commands[1])<maximum_row,'shell background shares row depth')
        assert(maximum_row<minimum_field and minimum_field<minimum_text,'retained fields or text share changing background depth')
    end
    local initial=menu.compose(1920,1080);verify(initial)
    local second=text_command(menu,'Second option')
    menu.tick({down=function()return false end,mouse=function()return second.x+4,second.y+4 end})
    local hovered=menu.compose(1920,1080);verify(hovered)
    assert(#initial==#hovered,'hover changed primitive count and shifted retained fields')
end)

test('Escape dismisses active editors before menu and editors own configured shortcut',function()
    local api=Core.new();api.menu_toggle_key=46
    local handle=api.register({id='escape',name='Escape',pages={{id='p',name='Page',require_confirmation=false,controls={
        {id='choice',type='choice',presentation='dropdown',label='Choice',choices={'A','B'},default=1},
        {id='binding',type='keybind',label='Binding',default=120,on_change=function()end}
    }}}})
    local menu=Menu.new(api);menu.visible=true;menu.focus='settings';menu.compose(1920,1080)
    menu.key(13);assert(menu.dropdown);menu.key(27);assert(menu.visible and not menu.dropdown)
    menu.row=2;menu.key(13);assert(menu.capture)
    menu.key(46)
    assert(menu.visible and not menu.capture and handle.get('binding')==46,'Delete closed its own binding editor')
    menu.key(13);menu.key(27)
    assert(menu.visible and not menu.capture and handle.get('binding')==46,'Escape changed binding')
    menu.text_edit={text='existing'};menu.key(46)
    assert(menu.visible and menu.text_edit and menu.text_edit.text=='','Delete interrupted text ownership')
    menu.key(27);assert(menu.visible and not menu.text_edit)
    menu.color_picker={rgb={255,255,255}};menu.key(46)
    assert(menu.visible and menu.color_picker,'Delete interrupted color ownership')
    menu.key(27);assert(menu.visible and not menu.color_picker)
    menu.key(27);assert(not menu.visible)
end)

print('PASS '..passed..' focused UI interaction contracts')
