-- Actual composition and pointer hits; no native GUI or input attachment.
local Core=dofile('src/core.lua')
local Menu=dofile('src/menu.lua')
local count=0
local function find(commands)
    local label,button
    for _,command in ipairs(commands)do
        if not label and command.type=='text'and command.full_text=='Settings'then label=command end
        if command.ui_role=='settings_button'then button=command end
    end
    assert(label and button,'Settings header metadata missing')
    return label,button
end
local function measure(factor)
    return function(value,size)
        local width=0
        for glyph in value:gmatch('.')do width=width+size*(glyph=='s'and .84 or .82)end
        return #value>1 and width*factor or width
    end
end
local function setup(metric,font_size,scale)
    local api=Core.new();api.settings_mod_id='mcm';api.settings_page_id='mcm_settings'
    api.register({id='mcm',name='MCM',pages={
        {id='general',name='General',controls={{id='enabled',type='toggle',label='Enabled',default=true}}},
        {id='mcm_settings',name='Settings',require_confirmation=false,controls={}}
    }})
    local menu=Menu.new(api,metric);menu.visible=true;menu.window_width=1100;menu.window_height=600
    menu.font_scale=font_size/20;menu.ui_scale=scale
    return menu
end
local function verify(menu,metric,w,h)
    local commands=menu.compose(w,h);local label,button=find(commands);local bounds=menu.window_bounds
    assert(label.text=='Settings','Settings was clipped to '..label.text)
    local glyph_width=0
    for glyph in label.full_text:gmatch('.')do glyph_width=glyph_width+(metric and metric(glyph,label.size)or label.size*.62)end
    local native_width=metric and metric(label.full_text,label.size)or glyph_width
    assert(label.text_width>=glyph_width,'Settings glyph budget is too small')
    assert(label.x+native_width<=button.x+button.w-12*bounds.scale+.001,'Settings native extent exceeded padding')
    assert(button.x>=bounds.x and button.x+button.w<=bounds.x+bounds.w-60*bounds.scale+.001,'Settings button exceeded minimum window bounds')
    assert(math.abs(button.h-34*bounds.scale)<.001,'Settings hit height changed with font size')
    return label,button
end

-- Whole-word kerning can be narrower or wider than the sum used by text.flow.
for _,metric in ipairs({measure(.72),measure(1),measure(1.15),false})do
    for font_size=16,26 do
        for _,scale in ipairs({.75,1,1.5})do
            for _,screen in ipairs({{1920,1080},{800,600}})do
                local menu=setup(metric or nil,font_size,scale)
                local label,button=verify(menu,metric or nil,screen[1],screen[2])
                local down=false;local px,py=button.x+button.w-8*menu.window_bounds.scale,button.y+button.h/2
                local input={down=function(code)return code==1 and down end,mouse=function()return px,py end}
                menu.tick(input);menu.advance(5);verify(menu,metric or nil,screen[1],screen[2])
                down=true;menu.tick(input);assert(menu.page==2,'right padded Settings hit did not open the page')
                down=false;menu.tick(input);verify(menu,metric or nil,screen[1],screen[2])
                count=count+1
            end
        end
    end
end
print('PASS full Settings label, native/glyph kerning budgets, minimum window bounds and padded hits across '..count..' font/scale/metric/resolution cases')
