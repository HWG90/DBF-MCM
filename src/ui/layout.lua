-- Logical geometry: resizing adds useful room without stretching label/control gaps.
local L={row_step=40,row_height=34,column_gap=28,max_row_width=960,max_sidebar=400,min_sidebar=250}
local function clamp(value,minimum,maximum)return math.max(minimum,math.min(maximum,value))end
function L.sidebar(width,window_width)
    return clamp(width or 330,L.min_sidebar,math.min(L.max_sidebar,window_width-700))
end
function L.rows(available,controls,measure,size,scale)
    local width=math.min(available,L.max_row_width)
    local label=200
    for _,c in ipairs(controls or {})do
        if c.type~='text'and c.type~='section'and c.label then
            local value=string.rep('  ',c.depth or 0)..tostring(c.label)
            local ok,measured=pcall(measure,value,size*scale)
            if ok and type(measured)=='number'and measured==measured and measured<math.huge then label=math.max(label,measured/scale)end
        end
    end
    -- A common starting edge is easier to scan than controls pinned to the window.
    local field=math.min(360,math.max(180,width*.48))
    local anchor=clamp(label+20,200,math.min(400,width-field-16))
    return {width=math.min(width,anchor+field),anchor=anchor,label_width=anchor-16,field_width=field}
end
function L.choice_presentation(presentation)
    return presentation=='selector'and 'selector'or 'dropdown'
end
function L.control(kind,field_width,preferred,presentation)
    if kind=='slider'then return math.min(300,field_width)
    elseif kind=='input'then return math.min(300,field_width)
    elseif kind=='color'then return math.min(230,field_width)
    elseif kind=='toggle'or kind=='keybind'then return math.min(175,field_width)
    elseif kind=='choice'then return math.min(preferred or 280,field_width-(L.choice_presentation(presentation)=='selector'and 60 or 0))
    else return math.min(preferred or 175,field_width)end
end
return L
