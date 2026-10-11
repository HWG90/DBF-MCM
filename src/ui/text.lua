local M={}
local function glyphs(value)
    local result={};for glyph in tostring(value):gmatch('[%z\1-\127\194-\244][\128-\191]*')do result[#result+1]=glyph end
    return result
end
local function extent(value,size,measure)
    if measure then
        local width=measure(value,size)
        if type(width)=='number'and width>=0 and width<math.huge then return width end
    end
    return #glyphs(value)*size*.62
end
-- Whole-glyph viewport: never split UTF-8 or draw outside the allotted width.

function M.flow(value,width,size,time,measure)

    value=tostring(value)
    if extent(value,size,measure)<=width then return value,false end
    local chars=glyphs(value);local last=1
    while last<#chars and extent(table.concat(chars,'',last),size,measure)>width do last=last+1 end

    local travel=math.max(0,last-1);local duration=travel*.25

    local phase=math.max(0,time or 0)%(duration*2+3)

    local offset=phase<1.5 and 0 or phase<1.5+duration and math.floor((phase-1.5)/.25) or phase<3+duration and travel or travel-math.floor((phase-3-duration)/.25)

    local first=math.max(1,math.min(last,offset+1));local visible=''
    for i=first,#chars do
        local candidate=visible..chars[i]
        if extent(candidate,size,measure)>width then break end
        visible=candidate
    end
    return visible,true

end

-- Fit at most 32 whole glyphs; padding and arrows share the available budget.
function M.control_width(value,minimum,available,padding,size,measure)
    local chars=glyphs(value)
    local width=extent(table.concat(chars,'',1,math.min(32,#chars)),size,measure)
    return math.max(0,math.min(available,math.max(minimum,width+padding)))
end

-- Renderer-independent lightweight rich text: paragraphs, lists, headings and emphasis.

function M.rich(value,width,size,measure)

    local lines={};value=tostring(value or ''):gsub('\r\n','\n')

    for paragraph in (value..'\n'):gmatch('(.-)\n')do

        local heading,body=paragraph:match('^(#+)%s+(.+)$');local font=heading and size+3 or size

        body=body or paragraph;body=body:gsub('^%s*[-*]%s+','- ')

        local line,used={},0;local strong,emphasis=false,false

        local function flush()lines[#lines+1]={spans=line,size=font};line={};used=0 end
        local function appended_width(value,style)
            local last=line[#line]
            if last and last.style==style then return used-last.width+extent(last.text..value,font,measure)end
            return used+extent(value,font,measure)
        end

        local function add(word,style)

            for _,glyph in ipairs(glyphs(word))do
                if appended_width(glyph,style)>width and #line>0 then flush()end

                if not(glyph==' ' and #line==0)then

                    used=appended_width(glyph,style)
                    local last=line[#line]
                    if last and last.style==style then last.text=last.text..glyph;last.width=extent(last.text,font,measure)
                    else line[#line+1]={text=glyph,style=style,width=extent(glyph,font,measure)}end

                end

            end

        end

        local index=1

        while index<=#body do

            if body:sub(index,index+1)=='**' then strong=not strong;index=index+2

            elseif body:sub(index,index)=='*' then emphasis=not emphasis;index=index+1

            else

                local stop=body:find('*',index,true) or (#body+1);local chunk=body:sub(index,stop-1)

                for word in chunk:gmatch('%S+%s*')do

                    local style=heading and 'heading' or strong and 'strong' or emphasis and 'emphasis' or 'plain'
                    if appended_width(word,style)>width and #line>0 then flush()end
                    add(word,style)

                end

                index=stop

            end

        end

        flush()

    end

    return lines

end

return M
