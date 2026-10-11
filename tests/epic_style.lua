-- Actual composition and input contracts; no game, native font or capture attachment.
local Core=dofile('src/core.lua')
local Menu=dofile('src/menu.lua')
local Theme=dofile('src/ui/theme.lua')
local passed=0
local function test(name,fn)
    local ok,why=pcall(fn);assert(ok,name..': '..tostring(why))
    passed=passed+1;print('PASS '..name)
end
local function same(a,b)return a and b and a[1]==b[1]and a[2]==b[2]and a[3]==b[3]end
local function near(a,b)return math.abs(a-b)<.01 end
local function plane(command)return math.floor((command.layer or 100)+(command.type=='text'and 1 or 0))end
local function text(commands,value,popup)
    for _,command in ipairs(commands)do
        if command.type=='text'and (command.full_text or command.text)==value and (popup==nil or not not command.popup==popup)then return command end
    end
    error('Missing composed text '..value)
end
local function fill(commands,label)
    for _,command in ipairs(commands)do
        if command.type=='rect'and command.ui_role=='control_fill'and command.x<=label.x and label.x<command.x+command.w
            and command.y<=label.y and label.y<=command.y+command.h then return command end
    end
    error('Missing control surface for '..tostring(label.full_text or label.text))
end
local function edges(commands,body)
    local found={}
    for _,command in ipairs(commands)do
        if command.type=='rect'and command.ui_role=='control_border'then
            local horizontal=near(command.x,body.x)and near(command.w,body.w)and near(command.h,2)
                and (near(command.y,body.y)or near(command.y+command.h,body.y+body.h))
            local vertical=near(command.w,2)and near(command.y,body.y+2)and near(command.h,body.h-4)
                and (near(command.x,body.x)or near(command.x+command.w,body.x+body.w))
            if horizontal or vertical then found[#found+1]=command end
        end
    end
    assert(#found==4,'Expected four retained two-pixel edge strips, got '..#found)
    for _,edge in ipairs(found)do
        assert(edge.x>=body.x-.01 and edge.y>=body.y-.01 and edge.x+edge.w<=body.x+body.w+.01 and edge.y+edge.h<=body.y+body.h+.01,'Outline escaped its field')
        local cx,cy=body.x+body.w/2,body.y+body.h/2
        assert(not(cx>edge.x and cx<edge.x+edge.w and cy>edge.y and cy<edge.y+edge.h),'Outline paints over the control interior')
    end
    return found
end
local function setup()
    local counts={writes=0,actions=0,blocked=0,choice=0,toggle=0}
    local api=Core.new({load=function()return{}end,save=function()counts.writes=counts.writes+1;return true end})
    local handle=api.register({id='fixture',name='Fixture',pages={{id='appearance',name='Appearance',require_confirmation=true,controls={
        {type='section',label='WORKSPACE TOOLS'},
        {id='action',type='button',label='Action',button_label='RUN ACTION',require_confirmation=false,on_activate=function()counts.actions=counts.actions+1;return true end},
        {id='profile',type='input',label='Profile',default='Mission ready'},
        {id='choice',type='choice',label='Selection',presentation='dropdown',choices={'First','Second','Third'},default=1,on_change=function()counts.choice=counts.choice+1 end},
        {id='accent',type='color',label='Accent',default='#FFFFFF'},
        {id='enabled',type='toggle',label='Enabled',default=false,on_change=function()counts.toggle=counts.toggle+1 end},
        {id='checked',type='toggle',presentation='checkbox',label='Include metadata',default=false},
        {id='blocked',type='button',label='Blocked',button_label='BLOCKED',disabled=true,require_confirmation=false,on_activate=function()counts.blocked=counts.blocked+1 end},
    }}}})
    local function measure(value,size)
        local count=0;for _ in value:gmatch('[%z\1-\127\194-\244][\128-\191]*')do count=count+1 end
        return count*size*.42
    end
    local menu=Menu.new(api,measure);menu.visible=true;menu.focus='mods';menu.row=2
    menu.text_metrics=function(size)return{min_y=-size*.2,max_y=size*.65,height=size*.85}end
    local screen={1920,1080};local px,py,down=0,0,false
    local input={down=function(key)return key==1 and down end,mouse=function()return px,py end}
    local function compose()return menu.compose(screen[1],screen[2])end
    local function pointer(x,y,pressed)px,py,down=x,y,pressed==true;menu.tick(input);return compose()end
    local function tap(body)
        local x,y=body.x+body.w/2,body.y+body.h/2
        pointer(x,y,false);pointer(x,y,true);return pointer(x,y,false)
    end
    local function tap_text(label)return tap({x=label.x,y=label.y,w=8,h=8})end
    return{api=api,handle=handle,menu=menu,counts=counts,compose=compose,pointer=pointer,tap=tap,tap_text=tap_text,screen=screen}
end

test('Epic workspace tokens preserve the legacy palette reference',function()
    assert(same(Theme.palette.background,{17,22,27})and same(Theme.palette.focus,{119,185,205}),'Legacy palette changed')
    assert(Theme.workspace and Menu.palette and same(Menu.palette.background,Theme.workspace.background),'Composer does not expose the Epic workspace skin')
    local expected={background={12,14,16},panel={19,21,23},header={25,27,29},border={62,66,69},border_hover={106,111,114},
        white={234,235,228},muted={154,159,159},focus={244,202,53},hover={29,31,33},selected={43,39,24},field={29,31,34},disabled={105,111,113}}
    for key,value in pairs(expected)do assert(same(Menu.palette[key],value),'Workspace token mismatch: '..key)end
end)

test('role typography and native ink remain inside fields across font and UI scales',function()
    local s=setup();local cases=0
    for _,font in ipairs({16,20,26})do for _,scale in ipairs({.75,1,1.5})do for _,screen in ipairs({{1920,1080},{3840,2160}})do
        s.menu.font_scale=font/20;s.menu.ui_scale=scale;s.screen[1],s.screen[2]=screen[1],screen[2]
        local commands=s.compose();local body=text(commands,'RUN ACTION');local surface=fill(commands,body)
        local title,heading=text(commands,'Appearance'),text(commands,'WORKSPACE TOOLS');local unit=s.menu.window_bounds.scale
        assert(near(body.size,font*unit)and not body.text_bold,'Body role/weight changed')
        assert(title.text_role=='title'and title.text_bold and near(title.size,font*1.5*unit),'Page title hierarchy changed')
        assert(heading.text_role=='heading'and heading.text_bold and near(heading.size,font*1.15*unit),'Section hierarchy changed')
        assert(body.y-body.size*.2>=surface.y-.01 and body.y+body.size*.65<=surface.y+surface.h+.01,'Native ink escaped button padding')
        for _,command in ipairs(commands)do
            if command.type=='text'and command.text_role~='heading'and command.text_role~='title'then assert(not command.text_bold,'Body/hint text became bold')end
        end
        edges(commands,surface);cases=cases+1
    end end end
    assert(cases==18)
end)

test('quiet actions filled fields and selected controls have distinct feedback without hover writes',function()
    local s=setup();local T=Menu.palette;local commands=s.compose()
    local label=text(commands,'RUN ACTION');local action=fill(commands,label);local field=fill(commands,text(commands,'Mission ready'))
    assert(same(action.c,T.panel)and same(field.c,T.field)and not same(action.c,field.c),'Actions and fields lost their distinction')
    for _,edge in ipairs(edges(commands,action))do assert(same(edge.c,T.border),'Quiet action border changed')end
    local row,focus=s.menu.row,s.menu.focus
    commands=s.pointer(action.x+action.w/2,action.y+action.h/2,false)
    action=fill(commands,text(commands,'RUN ACTION'))
    assert(same(action.c,T.hover),'Action has no neutral hover fill')
    for _,edge in ipairs(edges(commands,action))do assert(same(edge.c,T.border_hover),'Action hover did not brighten its outline')end
    assert(s.menu.row==row and s.menu.focus==focus and s.counts.writes==0 and s.counts.actions==0,'Hover changed focus or state')
    s.pointer(0,0,false);s.menu.row=1;s.menu.focus='settings';commands=s.compose();action=fill(commands,text(commands,'RUN ACTION'))
    assert(same(action.c,T.selected),'Selected action lost its warm tint')
    for _,edge in ipairs(edges(commands,action))do assert(same(edge.c,T.focus),'Focused selection lacks a gold outline')end
    local disabled=fill(commands,text(commands,'BLOCKED'))
    assert(same(disabled.c,T.panel)and same(text(commands,'BLOCKED').c,T.disabled),'Disabled surface/ink changed')
end)

test('secondary clicks and text field ownership keep existing callbacks',function()
    local s=setup();local commands=s.compose()
    s.tap(fill(commands,text(commands,'RUN ACTION')));assert(s.counts.actions==1 and s.counts.writes==0,'Action callback/save behavior changed')
    commands=s.compose();s.tap(fill(commands,text(commands,'BLOCKED')));assert(s.counts.blocked==0,'Disabled action fired')
    commands=s.compose();s.tap(fill(commands,text(commands,'Mission ready')))
    assert(s.menu.text_edit and s.menu.text_edit.control.id=='profile','Text field no longer owns editing')
    s.menu.key(27);assert(not s.menu.text_edit and s.handle.get('profile')=='Mission ready'and s.counts.writes==0,'Cancel changed the field value')
end)

test('default sliding switch and explicit checkbox keep staged marks visible during real hover',function()
    local s=setup();local commands=s.compose();local box,marks
    local function switch(list)
        local track,thumb
        for _,command in ipairs(list)do if command.ui_role=='switch_track'then track=command elseif command.ui_role=='switch_thumb'then thumb=command end end
        assert(track and thumb and near(track.w,48*s.menu.window_bounds.scale),'Default toggle lost its sliding switch')
        assert(plane(thumb)>plane(track),'Switch thumb shares its track depth')
        return track,thumb
    end
    local function checkbox(list)
        local result,count=nil,0
        for _,command in ipairs(list)do
            if command.ui_role=='checkbox_box'then result=command end
            if command.ui_role=='checkbox_mark'then count=count+1 end
        end
        assert(result and near(result.w,result.h)and near(result.w,22*s.menu.window_bounds.scale),'Toggle lacks a 22-unit square checkbox')
        return result,count
    end
    local track,off_thumb=switch(commands)
    box,marks=checkbox(commands);assert(marks==0,'Unchecked explicit checkbox displays a mark')
    s.tap(off_thumb);commands=s.compose();local _,on_thumb=switch(commands)
    assert(near(on_thumb.x-off_thumb.x,24*s.menu.window_bounds.scale),'Saved switch state did not move the thumb')
    assert(s.handle.preview('enabled')and not s.handle.get('enabled')and s.counts.writes==0,'Switch acceptance bypassed staging')
    commands=s.pointer(on_thumb.x+on_thumb.w/2,on_thumb.y+on_thumb.h/2,false)
    local _,hover_thumb=switch(commands)
    assert(near(hover_thumb.x,on_thumb.x)and s.handle.preview('enabled')and s.counts.writes==0,'Hover moved or saved the switch')
    local switch_field=fill(commands,text(commands,'ON'))
    assert(same(switch_field.c,Menu.palette.field_hover)and plane(switch_field)<plane(hover_thumb),'Real switch hover has unsafe fill/depth')
    box,marks=checkbox(commands);assert(marks==0,'Switch toggled the separate checkbox owner')
    s.tap(box);commands=s.compose();box,marks=checkbox(commands)
    assert(marks>1 and s.handle.preview('checked')and not s.handle.get('checked')and s.handle.preview('enabled')and s.counts.writes==0,'Checkbox acceptance changed staging or another owner')
    for _,command in ipairs(commands)do if command.ui_role=='checkbox_mark'then
        assert(command.x>=box.x-.01 and command.y>=box.y-.01 and command.x+command.w<=box.x+box.w+.01 and command.y+command.h<=box.y+box.h+.01,'Check geometry escaped its square')
        assert(plane(command)>plane(box),'Checkbox mark shares its box depth')
    end end
    -- Replay the actual composed scene in retained mode. Hover creates a new
    -- field fill while unchanged check primitives must keep their native IDs.
    local View=dofile('src/view.lua');local world={};local serial=0;local retained={}
    local function allocate(kind,position,size)
        serial=serial+1;retained[serial]={kind=kind,x=position.x,y=position.y,z=position.z,w=size and size.x,h=size and size.y};return serial
    end
    local function destroy(_,id)retained[id]=nil end
    local sr={Application={main_world=function()return world end,worlds=function()return{world}end},World={create_screen_gui=function()return{}end,destroy_gui=function()end},
        Vector3=function(x,y,z)return{x=x,y=y,z=z}end,Vector2=function(x,y)return{x=x,y=y}end,Color=function(...)return{...}end,
        Gui={rect=function(_,position,size)return allocate('rect',position,size)end,text=function(_,_,_,_,_,position)return allocate('text',position)end,
            triangle=function(_,_,_,_,layer)return allocate('triangle',{z=layer})end,destroy_rect=destroy,destroy_text=destroy,destroy_triangle=destroy}}
    local native=View.new(sr);native.draw(commands);local check_ids={}
    for _,command in ipairs(commands)do if command.ui_role=='checkbox_mark'then
        for id,p in pairs(retained)do if p.kind=='rect'and near(p.x,command.x)and near(p.y,command.y)and near(p.w,command.w)and near(p.h,command.h)then check_ids[id]=command end end
    end end
    local ids=0;for _ in pairs(check_ids)do ids=ids+1 end;assert(ids==marks,'Composed check primitives were not painted')
    s.pointer(0,0,false);commands=s.compose();native.draw(commands)
    local hovered=s.pointer(box.x+box.w/2,box.y+box.h/2,false);local hovered_box,hovered_marks=checkbox(hovered);native.draw(hovered)
    assert(hovered_marks==marks and near(hovered_box.x,box.x),'Hover removed or moved the check geometry')
    for id,mark in pairs(check_ids)do assert(retained[id]and retained[id].z==plane(mark),'Hover discarded a retained check primitive')end
    assert(s.handle.preview('checked')and not s.handle.get('checked')and s.counts.writes==0 and s.counts.toggle==0,'Hover saved a draft or fired a callback')
    native.release();assert(next(retained)==nil,'Composed vector/check primitives leaked')
end)

test('dropdown preview commits once through the gold Apply action',function()
    local s=setup();local commands=s.compose();s.tap(fill(commands,text(commands,'First')))
    assert(s.menu.dropdown and s.handle.get('choice')==1 and s.counts.choice==0,'Opening dropdown committed a value')
    commands=s.compose();local third=text(commands,'Third',true)
    s.pointer(third.x+3,third.y+3,false);assert(s.handle.get('choice')==1 and s.counts.writes==0,'Popup hover committed a value')
    s.tap_text(third);assert(not s.menu.dropdown and s.handle.preview('choice')==3 and s.handle.get('choice')==1,'Dropdown acceptance bypassed pending edits')
    commands=s.compose();local ink=text(commands,'APPLY');local apply=fill(commands,ink)
    assert(same(apply.c,Menu.palette.focus)and ink.c[1]<=40 and ink.c[2]<=40 and ink.c[3]<=40,'Primary action lost gold fill/dark ink')
    s.tap(apply);assert(s.handle.get('choice')==3 and s.counts.choice==1 and s.counts.writes==1,'Apply changed commit/callback count')
end)

test('modal coverage suppresses underlying action feedback and callbacks',function()
    for _,kind in ipairs({'dropdown','color'})do
        local s=setup();local commands=s.compose();local action=fill(commands,text(commands,'RUN ACTION'))
        local target=kind=='dropdown'and 'First'or '#FFFFFF'
        s.tap(fill(commands,text(commands,target)));assert(kind=='dropdown'and s.menu.dropdown or kind=='color'and s.menu.color_picker,'Modal did not open')
        commands=s.pointer(action.x+action.w/2,action.y+action.h/2,false)
        local covered=fill(commands,text(commands,'RUN ACTION',false))
        assert(same(covered.c,Menu.palette.panel),'Covered action reacts through a modal')
        for _,edge in ipairs(edges(commands,covered))do assert(same(edge.c,Menu.palette.border),'Covered outline reacts through a modal')end
        s.tap(action);assert(s.counts.actions==0 and s.counts.writes==0,'Covered action wrote or fired')
        -- An outside dropdown click dismisses it and is consumed; an open
        -- picker still owns Escape. Neither path may click through or save.
        if s.menu.dropdown or s.menu.color_picker then s.menu.key(27)end
        assert(s.menu.visible and s.handle.get('choice')==1 and s.handle.get('accent')=='#FFFFFF','Modal cancellation changed owner values')
    end
end)

test('integer paint order survives changing sidebar counts and keeps popups above the workspace',function()
    local s=setup();local original
    for iteration=1,2 do
        local commands=s.compose();local label=text(commands,'RUN ACTION');local body=fill(commands,label);local border=edges(commands,body)
        local row
        for _,command in ipairs(commands)do if command.ui_role=='setting_row'and command.x<=body.x and command.x+command.w>=body.x+body.w
            and command.y<=body.y and command.y+command.h>=body.y+body.h then row=command;break end end
        assert(row and plane(row)<plane(body),'Row background covers its control')
        for _,edge in ipairs(border)do assert(plane(body)<plane(edge)and plane(edge)<plane(label),'Fill/edge/text integer ordering is unsafe')end
        if original then assert(original.fill==plane(body)and original.edge==plane(border[1])and original.text==plane(label),'Sidebar command count moved unrelated text depth')
        else original={fill=plane(body),edge=plane(border[1]),text=plane(label)}end
        if iteration==1 then for index=1,8 do s.api.register({id='z'..index,name='Z extra '..index,pages={{id='general',name='General',controls={}}}})end end
    end
    for _,target in ipairs({'First','#FFFFFF'})do
        local commands=s.compose();s.tap(fill(commands,text(commands,target)))
        local maximum,minimum=-math.huge,math.huge
        for _,command in ipairs(s.compose())do
            if command.popup then minimum=math.min(minimum,plane(command))else maximum=math.max(maximum,plane(command))end
        end
        assert(minimum<math.huge and minimum>maximum,'Popup primitives share the workspace plane')
        s.menu.key(27)
    end
end)

print('PASS '..passed..' Epic workspace styling and interaction contracts')
