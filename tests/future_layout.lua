local Core=dofile('src/core.lua');local Menu=dofile('src/menu.lua');local Layout=dofile('src/ui/layout.lua')
local passed=0
local function test(name,fn)local ok,why=pcall(fn);assert(ok,name..': '..tostring(why));passed=passed+1;print('PASS '..name)end
local function measure(value,size)return #value*size*.47 end
local function fixture()
    local api=Core.new();local h=api.register({id='layout',name='Layout fixture',pages={{id='main',name='General',controls={
        {id='enabled',type='toggle',label='Enabled',default=true},
        {id='scale',type='slider',label='Scale',min=0,max=100,step=1,default=50},
        {id='checked',type='toggle',presentation='checkbox',label='Include optional metadata',default=true},
        {id='text',type='input',label='Setup name',default='Mission ready'},
        {id='choice',type='choice',label='Display mode',choices={'First','Second'},default=1},
    }}}});local m=Menu.new(api,measure);m.visible=true;m.focus='settings'
    return m,h
end
local function find(commands,role)for _,c in ipairs(commands)do if c.ui_role==role then return c end end;error('Missing '..role)end
local function z(c)return(c.layer or 100)+(c.type=='text'and 1 or 0)end
test('resizing clamps control distance and sidebar without changing scale',function()
    local m=fixture();local anchors={}
    for _,width in ipairs({1100,1500,1920,2560})do
        m.window_width=width;m.window_height=820;m.sidebar_width=900
        local commands=m.compose(2560,1080);local bounds=m.window_bounds
        assert(m.sidebar_width<=Layout.max_sidebar and bounds.scale==1)
        assert(m.layout_geometry.row_width<=Layout.max_row_width)
        assert(m.layout_geometry.control_offset<=400)
        anchors[#anchors+1]=m.layout_geometry.control_offset
        local switch=find(commands,'switch_track');assert(switch.w==48 and switch.h==16,'Resizing stretched a control')
        for _,c in ipairs(commands)do if c.type=='text'and c.full_text=='Enabled'then assert(c.size==20,'Resizing changed body text scale')end end
    end
    assert(anchors[2]==anchors[3]and anchors[3]==anchors[4],'Available room pulled controls away from labels')
    assert(m.layout_geometry.inspector,'Large window leaves spare room unused')
end)
test('switch thumb and explicit checkbox mark sit above hover fills and borders',function()
    local m,h=fixture();local commands=m.compose(1920,1080)
    local thumb,track,box,mark=find(commands,'switch_thumb'),find(commands,'switch_track'),find(commands,'checkbox_box'),find(commands,'checkbox_mark')
    assert(z(thumb)>z(track)and z(mark)>z(box))
    local filled=0
    for _,c in ipairs(commands)do if c.ui_role=='checkbox_box'then filled=filled+1 end end
    assert(filled==1,'Default toggle was rendered as checkbox')
    m.pointer_x,m.pointer_y=thumb.x+thumb.w/2,thumb.y+thumb.h/2
    local hovered=m.compose(1920,1080);local next_thumb=find(hovered,'switch_thumb')
    assert(next_thumb.x==thumb.x and z(next_thumb)==z(thumb)and h.get('enabled')==true,'Hover moved or mutated the switch')
    for _,c in ipairs(hovered)do if c.ui_role=='control_fill'or c.ui_role=='control_border'then assert(z(c)<z(next_thumb),'Hover surface covers the switch')end end
end)
test('clamped field targets remain inside their row at font and UI scale extremes',function()
    local cases=0
    for _,scale in ipairs({.75,1,1.5})do for _,font in ipairs({.8,1,1.3})do
        local m=fixture();m.window_width=1100;m.window_height=600;m.ui_scale=scale;m.font_scale=font
        local commands=m.compose(1920,1080);local b=m.window_bounds
        for _,c in ipairs(commands)do if c.ui_role=='switch_track'or c.ui_role=='switch_thumb'or c.ui_role=='checkbox_box'then
            assert(c.x>=b.x and c.x+c.w<=b.x+b.w and c.y>=b.y and c.y+c.h<=b.y+b.h,'Control escaped window')
        end end
        cases=cases+1
    end end
    assert(cases==9)
end)
test('skull and both clipped hazard bands use retained vector geometry',function()
    local m=fixture();local commands=m.compose(1920,1080);local b=m.window_bounds;local skull,top,bottom=0,0,0
    for _,c in ipairs(commands)do if c.type=='triangle'then
        assert(#c.points==6)
        for i=1,6,2 do assert(c.points[i]>=b.x and c.points[i]<=b.x+b.w and c.points[i+1]>=b.y and c.points[i+1]<=b.y+b.h,'Branding escaped window')end
        if c.ui_role=='emblem'then skull=skull+1 end
        if c.ui_role=='hazard'then
            assert(c.surface_offset>=2,'Retained hazard stripe shares its fill plane')
            if c.points[2]>b.y+b.h/2 then top=top+1 else bottom=bottom+1 end
        end
    end end
    assert(skull>0 and top>0 and bottom>0)
end)
test('two authored columns move the HUD preview into its own window',function()
    local calls=0;local api=Core.new()
    api.register({id='hud',name='HUD',pages={{id='two',name='Two columns',render_preview=function()calls=calls+1;return{}end,controls={
        {id='left',type='toggle',label='Left',column=1,default=true},
        {id='right',type='toggle',label='Right',column=2,default=true},
    }}}})
    local m=Menu.new(api,measure);m.visible=true;m.window_width=1920
    local commands=m.compose(1920,1080);local button=false
    for _,c in ipairs(commands)do if c.type=='text'and c.text=='OPEN HUD PREVIEW'then button=true end end
    assert(button and calls==0,'Inline preview overlays the authored second column')
end)
test('right clicking a switch opens bounded options without changing its value',function()
    local m,h=fixture();local commands=m.compose(1920,1080);local thumb=find(commands,'switch_thumb')
    local down=false;local x,y=thumb.x+4,thumb.y+4
    local input={down=function(code)return code==2 and down end,mouse=function()return x,y end}
    m.tick(input);down=true;m.tick(input);down=false;m.tick(input)
    assert(m.context_menu and h.get('enabled')==true,'Right click toggled or ignored the setting')
    commands=m.compose(1920,1080);local bounds=m.context_menu.bounds;local window=m.window_bounds
    assert(bounds.x>=window.x and bounds.y>=window.y and bounds.x+bounds.w<=window.x+window.w and bounds.y+bounds.h<=window.y+window.h)
    m.visible=false;m.compose(1920,1080);m.visible=true;m.compose(1920,1080)
    assert(not m.context_menu,'Hidden menu retained context options')
end)
print(passed..' future layout contracts passed')
