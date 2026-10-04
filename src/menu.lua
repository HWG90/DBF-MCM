-- MCM layout/controller. Drawing is isolated from registry and settings storage.

local M={}

-- Whole-glyph viewport: never split UTF-8 or draw outside the allotted width.

function M.flow(value,width,size,time,measure)

    local glyphs={};for glyph in tostring(value):gmatch('[%z\1-\127\194-\244][\128-\191]*')do glyphs[#glyphs+1]=glyph end

    local widths,total={},0

    for i,g in ipairs(glyphs)do widths[i]=(measure and measure(g,size)) or size*.62;total=total+widths[i]end

    if total<=width then return tostring(value),false end

    local last=#glyphs;local tail=0

    while last>1 and tail+widths[last]<=width do tail=tail+widths[last];last=last-1 end

    last=math.min(#glyphs,last+1)

    local travel=math.max(0,last-1);local duration=travel*.25

    local phase=math.max(0,time or 0)%(duration*2+3)

    local offset=phase<1.5 and 0 or phase<1.5+duration and math.floor((phase-1.5)/.25) or phase<3+duration and travel or travel-math.floor((phase-3-duration)/.25)

    local first=math.max(1,math.min(last,offset+1));local visible,used={},0

    for i=first,#glyphs do if used+widths[i]>width then break end;visible[#visible+1]=glyphs[i];used=used+widths[i]end

    return table.concat(visible),true

end

-- Fit at most 32 whole glyphs; padding and arrows share the available budget.
function M.control_width(value,minimum,available,padding,size,measure)
    local width,count=0,0
    for glyph in tostring(value):gmatch('[%z\1-\127\194-\244][\128-\191]*')do
        if count==32 then break end
        count=count+1;width=width+((measure and measure(glyph,size)) or size*.62)
    end
    return math.max(0,math.min(available,math.max(minimum,width+padding)))
end

-- Renderer-independent lightweight rich text: paragraphs, lists, headings and emphasis.

function M.rich(value,width,size,measure)

    local lines={};value=tostring(value or ''):gsub('\r\n','\n')

    for paragraph in (value..'\n'):gmatch('(.-)\n')do

        local heading,body=paragraph:match('^(#+)%s+(.+)$');local font=heading and size+3 or size

        body=body or paragraph;body=body:gsub('^%s*[-*]%s+','• ')

        local spans,line,used={}, {},0;local strong,emphasis=false,false

        local function flush()lines[#lines+1]={spans=line,size=font};line={};used=0 end

        local function add(word,style)

            local glyphs={};for glyph in word:gmatch('[%z\1-\127\194-\244][\128-\191]*')do glyphs[#glyphs+1]=glyph end

            for _,glyph in ipairs(glyphs)do

                local gw=(measure and measure(glyph,font)) or font*.62

                if used+gw>width and #line>0 then flush()end

                if not(glyph==' ' and #line==0)then

                    local last=line[#line];if last and last.style==style then last.text=last.text..glyph;last.width=last.width+gw else line[#line+1]={text=glyph,style=style,width=gw}end

                    used=used+gw

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

                    local ww=0;for glyph in word:gmatch('[%z\1-\127\194-\244][\128-\191]*')do ww=ww+((measure and measure(glyph,font)) or font*.62)end

                    if used+ww>width and #line>0 then flush()end

                    add(word,heading and 'heading' or strong and 'strong' or emphasis and 'emphasis' or 'plain')

                end

                index=stop

            end

        end

        flush()

    end

    return lines

end

function M.new(api,measure)

    local self={visible=false,focus='mods',selected=1,page=1,row=1,mod_scroll=0,scroll=0,notice='',capture=false}

    local tree_expanded={};local tree_scroll=0;local tree_manual=false;local tree_max=0

    local nav_bounds;local nav_scroll=0;local nav_mod;local expanded={}

    local wheel_bounds;local wheel_remainder=0;local manual_scroll=false

    local drag,window_drag,color_drag,palette_drag,split_drag,preview_drag

    self.sidebar_width=330;self.help_scroll=0;local help_bounds;local help_key

    local hits={};local current;local held={}

    function self.recover()

        self.visible=false;self.capture=false;self.text_edit=nil;self.color_picker=nil;self.dropdown=nil;self.mouse_held=false

        drag=nil;window_drag=nil;color_drag=nil;palette_drag=nil;split_drag=nil;preview_drag=nil;self.preview_window=nil

        self.notice='Menu closed after an error; F10 reopens it'

    end

    local function active()

        local mods=api.list();self.selected=math.max(1,math.min(self.selected,#mods));current=mods[self.selected]

        if current then self.page=math.max(1,math.min(self.page,#current.pages));return current,current.pages[self.page]end

    end

    local section_state={}
    local function state_key(page,id)return tostring(current and current.id)..'/'..page.id..'/'..id end
    local function section_open(page,c)
        local value=section_state[state_key(page,c.id)]
        if value==nil then return not c.collapsed end
        return value
    end
    local function visible_controls(page)
        local rows,groups={},{}
        for _,c in ipairs(page and page.controls or {})do
            local visible=true
            for _,parent in ipairs(c.groups or {})do if groups[parent]==false then visible=false;break end end
            if c.collapsible then groups[c.id]=section_open(page,c)end
            if visible then rows[#rows+1]=c end
        end
        return rows
    end
    local function selectable(page)

        local rows={};for _,c in ipairs(visible_controls(page))do

            if c.collapsible or (c.type~='text' and c.type~='section') then rows[#rows+1]=c end

        end;return rows

    end

    local function change(c,direction)

        if not current or c.disabled then return end

        if c.collapsible then
            local key=state_key(c.page,c.id);local open=section_open(c.page,c)
            section_state[key]=direction==0 and not open or direction>0
            manual_scroll=false;return
        end
        local h=current.handle;local ok,err=true

        if c.type=='button' then if direction==0 then ok,err=(h.queue or h.activate)(c.id)end

        elseif c.type=='input' then self.text_edit={mod=current,control=c,text=(h.preview or h.get)(c.id),replace=true};self.notice='Type name; Enter accepts';return

        elseif c.type=='keybind' then self.capture=c;self.notice='Press a key. Escape cancels.';return

        elseif c.type=='color' then

            self.color_picker={mod=current,control=c,rgb=api.color_rgb((h.preview or h.get)(c.id))};return

        else

            local v=(h.preview or h.get)(c.id)

            if c.type=='toggle' then v=not v

            elseif c.type=='choice' then v=(v-1+(direction==0 and 1 or direction))%#c.choices+1

            elseif c.type=='slider' then v=math.max(c.min,math.min(c.max,v+(direction==0 and 1 or direction)*c.step))

            else return end

            ok,err=(h.edit or h.set)(c.id,v)

        end

        self.notice=ok and (c.type=='button' and (c.require_confirmation and 'Action awaiting confirmation' or (type(err)=='string' and err or 'Action executed')) or (c.page and c.page.require_confirmation and 'Pending confirmation' or 'Saved')) or ('Could not save: '..tostring(err))

    end

    function self.finish_color_field()

        local e=self.text_edit;if not e or not e.color_channel then return true end

        if not self.color_picker then self.text_edit=nil;return true end

        if e.color_channel=='hex' then

            local ok,rgb=pcall(api.color_rgb,e.text)

            if not ok then self.notice='Use six HEX digits';return false end

            self.color_picker.rgb=rgb

        else

            local n=tonumber(e.text)

            if not n or n%1~=0 or n<0 or n>255 then self.notice='RGB channels: integers 0-255';return false end

            self.color_picker.rgb[e.color_channel]=n

        end

        self.color_picker.hue,self.color_picker.saturation,self.color_picker.brightness=api.rgb_hsv(self.color_picker.rgb)

        self.text_edit=nil;self.notice='Color preview updated';return true

    end

    function self.commit_color()

        if not self.finish_color_field()then return end

        local p=self.color_picker;if not p then return end

        local called,ok,err=pcall(p.mod.handle.edit or p.mod.handle.set,p.control.id,p.rgb)

        if called and ok then self.notice=p.control.page.require_confirmation and 'Pending confirmation' or 'Saved';self.color_picker=nil

        else self.notice=tostring(called and err or ok)end

    end

    function self.key(code,ctrl)

        if code==121 then drag=nil;window_drag=nil;self.dropdown=nil;self.text_edit=nil;self.color_picker=nil end

        if code==121 then self.visible=not self.visible;self.capture=false;return end -- F10

        if not self.visible then return end

        if self.text_edit then

            local e=self.text_edit

            if code==27 then self.text_edit=nil;return end

            if code==9 and e.color_channel then self.finish_color_field();return end

            if code==13 then

                if e.color_channel then self.finish_color_field();return end

                local value=e.control.type=='input' and e.text or tonumber(e.text)

                if e.control.type~='input' and (not value or value~=value or value<e.control.min or value>e.control.max) then

                    self.notice='Enter a number from '..e.control.min..' to '..e.control.max;return

                end

                local called,ok,err=pcall(e.mod.handle.edit or e.mod.handle.set,e.control.id,value)

                if not called or not ok then self.notice=tostring(called and err or ok);return end

                self.notice=e.control.page and e.control.page.require_confirmation and 'Pending confirmation' or 'Saved';self.text_edit=nil;return

            end

            if ctrl and code==65 then e.replace=true;return end

            if code==8 then if e.replace then e.text=''else e.text=e.text:sub(1,-2)end;e.replace=false;return end

            if code==46 then e.text='';e.replace=false;return end

            local char

            if code>=48 and code<=57 then char=string.char(code)

            elseif code>=96 and code<=105 then char=tostring(code-96)

            elseif code==189 or code==109 then char='-'

            elseif code==190 or code==110 then char='.' end

            if e.control and e.control.type=='input' then if code>=65 and code<=90 then char=string.char(code) elseif code==32 then char=' ' end end

            if e.color_channel=='hex' and code>=65 and code<=70 then char=string.char(code)end

            if char and not ctrl then

                if e.replace then e.text='';e.replace=false end

                if #e.text<(e.control and e.control.type=='input' and 48 or 24) then e.text=e.text..char end

            end

            return

        end

        if self.color_picker then

            if code==27 then self.color_picker=nil;return end

            if code==13 then self.commit_color()end;return

        end

        if self.dropdown then

            local d=self.dropdown

            if code==27 then self.dropdown=nil;return end

            if code==38 or code==40 or code==33 or code==34 then

                local step=code==33 and -8 or (code==34 and 8 or (code==38 and -1 or 1))

                d.selected=math.max(1,math.min(#d.control.choices,d.selected+step))

                if d.selected<=d.scroll then d.scroll=d.selected-1 end

                if d.selected>d.scroll+8 then d.scroll=d.selected-8 end

                return

            end

            if code==13 then

                local ok,err=(d.mod.handle.edit or d.mod.handle.set)(d.control.id,d.selected)

                self.notice=ok and (d.control.page and d.control.page.require_confirmation and 'Pending confirmation' or 'Saved') or tostring(err)

                self.dropdown=nil;return

            end

            return

        end

        manual_scroll=false;tree_manual=false

        local mod,page=active();if not mod then if code==27 then self.visible=false end;return end

        if self.capture then

            local c=self.capture;self.capture=false

            if code~=27 then local ok,err=(mod.handle.edit or mod.handle.set)(c.id,code);self.notice=ok and (c.page and c.page.require_confirmation and 'Pending confirmation' or 'Binding saved') or tostring(err)end

            return

        end

        if code==27 then
            if self.preview_window then self.preview_window=nil;preview_drag=nil;return end
            self.visible=false;return end

        if (page.require_confirmation or next(page.actions)) and (code==120 or code==119)then

            local ok,err;if code==120 then ok,err=mod.handle.confirm(page.id)else ok,err=mod.handle.discard(page.id)end

            self.notice=ok and (code==120 and ('Confirmed and saved'..(err and '; '..tostring(err) or '')) or 'Pending edits discarded') or tostring(err);return

        end

        if code==9 then self.focus=self.focus=='mods' and 'settings' or 'mods';return end

        if code==33 or code==34 then

            self.page=(self.page-1+(code==33 and -1 or 1))%#mod.pages+1;self.row=1;self.scroll=0;return

        end

        if self.focus=='mods' then

            if code==38 or code==40 then self.selected=math.max(1,math.min(#api.list(),self.selected+(code==38 and -1 or 1)));self.page=1;self.row=1;self.scroll=0

            elseif code==13 or code==39 then self.focus='settings' end

        else

            local rows=selectable(page);self.row=math.max(1,math.min(self.row,#rows));local c=rows[self.row]

            if code==38 or code==40 then self.row=math.max(1,math.min(#rows,self.row+(code==38 and -1 or 1)))

            elseif c and (code==37 or code==39 or code==13) then change(c,code==13 and 0 or (code==37 and -1 or 1))

            elseif c and code==36 and c.type~='button' and not c.collapsible then local ok,err=(mod.handle.edit or mod.handle.set)(c.id,c.default);self.notice=ok and 'Default restored' or tostring(err)end

        end

    end

    function self.sidebar()

        local rows={}

        for index,mod in ipairs(api.list())do

            local open=tree_expanded[mod.id]==true

            rows[#rows+1]={kind='mod',mod=mod,index=index,open=open,depth=0}

            if open then

                local nodes=self.navigation(mod)

                for _,node in ipairs(nodes)do

                    if not (#(mod.categories or {})==1 and mod.categories[1].name=='HUD' and node.kind=='category' and node.depth==0)then

                        local item={};for k,v in pairs(node)do item[k]=v end

                        item.mod=mod;item.mod_index=index;item.depth=node.depth+1

                        if #(mod.categories or {})==1 and mod.categories[1].name=='HUD'then item.depth=math.max(1,item.depth-1)end

                        rows[#rows+1]=item

                    end

                end

            end

        end

        return rows

    end

    function self.navigation(mod)

        local rows={}

        local function children(parent,depth)

            for _,category in ipairs(mod.categories or {})do if category.parent==parent then

                local key=mod.id..'/'..category.id;local open=expanded[key];if open==nil then open=not category.collapsed end

                rows[#rows+1]={kind='category',category=category,key=key,open=open,depth=depth}

                if open then children(category.id,depth+1)end

            end end

            for index,page in ipairs(mod.pages)do if page.category==parent then rows[#rows+1]={kind='page',page=page,index=index,depth=depth}end end

        end

        children(nil,0);return rows

    end

    function self.wheel(delta,x,y)

        if not self.visible or self.capture or not wheel_bounds or not x or not y then return end

        if self.dropdown then

            local d=self.dropdown;d.scroll=math.max(0,math.min(math.max(0,#d.control.choices-8),d.scroll-delta/120*3));d.scroll=math.floor(d.scroll);return

        end

        if help_bounds and x>=help_bounds.x and x<=help_bounds.x+help_bounds.w and y>=help_bounds.y and y<=help_bounds.y+help_bounds.h then self.help_scroll=math.max(0,math.min(help_bounds.maximum,self.help_scroll-math.floor(delta/120)*3));return end

        if nav_bounds and x>=nav_bounds.x and x<=nav_bounds.x+nav_bounds.w and y>=nav_bounds.y and y<=nav_bounds.y+nav_bounds.h then

            nav_scroll=math.max(0,math.min(nav_bounds.maximum,nav_scroll-math.floor(delta/120)*3));return

        end

        local b=wheel_bounds;if x<b.x or x>b.x+b.w or y<b.y or y>b.y+b.h then return end

        wheel_remainder=wheel_remainder+delta

        local steps=wheel_remainder>=0 and math.floor(wheel_remainder/120) or math.ceil(wheel_remainder/120)

        wheel_remainder=wheel_remainder-steps*120;if steps==0 then return end

        local mod,page=active();if not mod then return end

        if x<b.split then

            tree_scroll=math.max(0,math.min(tree_max,tree_scroll-steps*3));tree_manual=true

        else

            self.scroll=math.max(0,math.min(math.max(0,(self.display_total or #page.controls)-12),self.scroll-steps*3));manual_scroll=true

        end

    end

    function self.tick(input)

        if not self.visible then

            local down=input.down(121);if down and not held[121] then self.key(121)end;held[121]=down

            return

        end

        if not self.color_picker and not drag and not window_drag and not self.text_edit and input.wheel and input.mouse then local delta=input.wheel();local x,y=input.mouse();self.wheel(delta,x,y)end

        for code=1,255 do local down=input.down(code);if down and not held[code] and code~=1 then self.key(code,input.down(17))end;held[code]=down end

        if self.visible and input.mouse then

            local x,y=input.mouse();if x and y and input.down(1) and not self.mouse_held then

                local valid=self.finish_color_field()

                if self.text_edit and self.text_edit.control and self.text_edit.control.type=='input' then

                    self.key(13)

                    valid=self.text_edit==nil

                end

                if valid then self.text_edit=nil end

                for i=#hits,1,-1 do local h=hits[i];if x>=h.x and x<=h.x+h.w and y>=h.y and y<=h.y+h.h then if valid then h.click(x,y)end;break end end

            end

            if palette_drag then

                if not self.color_picker or not input.down(1)then palette_drag=nil

                elseif x and y then palette_drag(x,y)end

            end

            if color_drag then

                if not self.color_picker or not input.down(1)then color_drag=nil

                elseif x and y then

                    self.color_picker.x=math.max(0,math.min(800,(x-color_drag.ox)/color_drag.scale-color_drag.dx))

                    self.color_picker.y=math.max(0,math.min(390,(y-color_drag.oy)/color_drag.scale-color_drag.dy))

                end

            end

            if split_drag then

                if not self.visible or not input.down(1)then split_drag=nil elseif x then self.sidebar_width=math.max(250,math.min(650,(x-split_drag.ox)/split_drag.scale))end

            end

            if preview_drag then
                if not self.visible or not self.preview_window or not input.down(1) then preview_drag=nil
                elseif x and y then
                    self.preview_window.x=math.max(0,math.min(preview_drag.max_x,x-preview_drag.dx))
                    self.preview_window.y=math.max(0,math.min(preview_drag.max_y,y-preview_drag.dy))
                end
            end
            if window_drag then

                if not self.visible or not input.down(1)then window_drag=nil

                elseif x and y then

                    self.window_x=math.max(0,math.min(window_drag.max_x,x-window_drag.dx))

                    self.window_y=math.max(0,math.min(window_drag.max_y,y-window_drag.dy))

                end

            end

            if drag then

                if not self.visible then drag=nil

                elseif input.down(1) then if x then drag.move(x)end

                else

                    local ok,err=(drag.mod.handle.edit or drag.mod.handle.set)(drag.control.id,drag.value)

                    self.notice=ok and (drag.control.page and drag.control.page.require_confirmation and 'Pending confirmation' or 'Saved') or ('Could not save: '..tostring(err));drag=nil

                end

            end

            self.mouse_held=input.down(1)

        else self.mouse_held=input.down(1)end

    end

    local text_age={};local elapsed=0

    function self.advance(dt)if self.visible then elapsed=elapsed+math.max(0,math.min(1,tonumber(dt) or 0))else elapsed=0;text_age={}end end

    function self.compose(w,h)

        if not self.visible then hits={};drag=nil;window_drag=nil;self.dropdown=nil;self.text_edit=nil;self.color_picker=nil;return {}end

        local commands={};hits={};local s=math.min(w/1920,h/1080);local ox,oy=math.max(0,math.min(math.max(0,w-1500*s),self.window_x or (w-1500*s)/2)),math.max(0,math.min(math.max(0,h-820*s),self.window_y or (h-820*s)/2))

        local visible_text_age={}

        self.window_x,self.window_y=ox,oy

        local white={224,230,234};local muted={145,156,165};local accent={244,202,53};local selection_text={24,30,35}

        local function rect(x,y,rw,rh,color,a)commands[#commands+1]={type='rect',x=ox+x*s,y=oy+y*s,w=rw*s,h=rh*s,c=color,a=a or 1}end

        local function text(x,y,value,size,color)

            commands[#commands+1]={type='text',x=ox+x*s,y=oy+y*s,text=tostring(value),size=(size or 20)*s,c=color or white,a=1}

        end

        local function bounded(x,y,value,size,color,width)

            local key=tostring(value)..'|'..x..'|'..y..'|'..width

            if not text_age[key]then text_age[key]=elapsed end

            visible_text_age[key]=text_age[key]

            local result=M.flow(value,width*s,size*s,elapsed-text_age[key],measure)

            text(x,y,result,size,color);commands[#commands].full_text=tostring(value);commands[#commands].text_width=width*s

        end

        local function hit(x,y,rw,rh,fn)hits[#hits+1]={x=ox+x*s,y=oy+y*s,w=rw*s,h=rh*s,click=fn}end

        local function scrollbar(role,x,y,height,total,visible,offset)

            if total<=visible then return end

            local thumb=math.max(20,height*visible/total)

            local travel=height-thumb;local maximum=total-visible

            local progress=math.max(0,math.min(1,offset/maximum))

            rect(x,y,5,height,{52,61,68})

            rect(x-1,y+travel*(1-progress),7,thumb,accent)

            commands[#commands].scrollbar=role

        end

        rect(0,0,1500,820,{16,20,24},.98);rect(0,760,1500,60,{28,33,38});rect(self.sidebar_width,60,2,700,muted)

        hit(0,760,1500,60,function(mx,my)

            if drag or self.capture then return end

            window_drag={dx=mx-ox,dy=my-oy,max_x=math.max(0,w-1500*s),max_y=math.max(0,h-820*s)}

        end)

        wheel_bounds={x=ox,y=oy+196*s,w=1500*s,h=504*s,split=ox+self.sidebar_width*s}

        text(30,777,'MOD CONFIGURATION',28,accent)

        rect(1445,775,38,30,{65,73,80});text(1457,782,'X',20,white)

        hit(1445,775,38,30,function()self.visible=false;self.capture=false;self.dropdown=nil;self.text_edit=nil;self.color_picker=nil end)

        text(25,715,'MODS',18,muted)

        local mods=api.list();local mod,page=active()

        local sidebar=self.sidebar();tree_max=math.max(0,#sidebar-18);tree_scroll=math.max(0,math.min(tree_scroll,tree_max))

        if not tree_manual then

            for i,node in ipairs(sidebar)do if node.kind=='mod' and node.index==self.selected then

                if i<=tree_scroll then tree_scroll=i-1 elseif i>tree_scroll+18 then tree_scroll=i-18 end

            end end

        end

        self.mod_scroll=tree_scroll

        for i=tree_scroll+1,math.min(#sidebar,tree_scroll+18)do

            local entry=sidebar[i];local y=671-(i-tree_scroll-1)*31;local x=25+entry.depth*16

            if entry.kind=='mod' then

                local selected=entry.index==self.selected

                if selected then rect(15,y-6,self.sidebar_width-30,30,accent)end

                text(x,y,entry.open and 'v' or '>',20,selected and selection_text or white)
                bounded(x+24,y,entry.mod.name,20,selected and selection_text or white,math.max(0,self.sidebar_width-39-x))

                hit(15,y-6,self.sidebar_width-30,30,function()

                    self.selected=entry.index;tree_expanded[entry.mod.id]=not entry.open;self.page=1;self.row=1;self.scroll=0;self.focus='settings';tree_manual=true

                end)

            else

                local last=true

                for next_index=i+1,#sidebar do

                    local next_entry=sidebar[next_index]

                    if next_entry.mod~=entry.mod or next_entry.depth<entry.depth then break end

                    if next_entry.depth==entry.depth then last=false;break end

                end

                rect(x-10,last and y+6 or y-7,1,last and 18 or 31,muted)

                commands[#commands].tree_branch={last=last,row_y=oy+y*s,junction=oy+(y+6)*s}

                rect(x-10,y+6,9,1,muted)

                if entry.kind=='category' then

                    rect(x-4,y-6,self.sidebar_width-15-x+4,30,{53,48,32})
                    rect(x-4,y-6,3,30,accent)
                    text(x+5,y,entry.open and 'v' or '>',20,{255,225,120})
                    bounded(x+29,y,entry.category.name,20,{255,225,120},math.max(0,self.sidebar_width-44-x))

                    hit(15,y-6,self.sidebar_width-30,30,function()expanded[entry.key]=not entry.open;tree_manual=true end)

                else

                    local selected=entry.mod_index==self.selected and entry.index==self.page

                    rect(x-4,y-6,self.sidebar_width-15-x+4,30,selected and {79,62,28} or {40,39,31})
                    rect(x-4,y-6,3,30,selected and {255,225,120} or accent)
                    bounded(x+5,y,entry.page.name,20,selected and {255,225,120} or white,math.max(0,self.sidebar_width-20-x))

                    hit(15,y-6,self.sidebar_width-30,30,function()self.selected=entry.mod_index;self.page=entry.index;self.row=1;self.scroll=0;manual_scroll=false;self.focus='settings';tree_manual=true end)

                end

            end

        end

        scrollbar('mods',self.sidebar_width-10,140,558,#sidebar,18,tree_scroll)

        if not mod then text(365,670,'No mods registered. See the author example.',24)

        else

            bounded(self.sidebar_width+35,712,mod.name,28,accent,1445-self.sidebar_width);bounded(self.sidebar_width+35,674,page.name,22,white,1445-self.sidebar_width)

            -- Sections are named in the sidebar; no redundant ordinal footer.

            if next(page.pending) or next(page.actions) then

                local pending=0;for _ in pairs(page.pending)do pending=pending+1 end;for _ in pairs(page.actions)do pending=pending+1 end

                text(850,90,'CONFIRM REQUIRED ('..pending..')',16,accent)

                rect(1160,81,135,29,{65,73,80});text(1170,90,'APPLY',18,accent)

                rect(1310,81,135,29,{65,73,80});text(1320,90,'DISCARD',18,white)

                hit(1160,81,135,29,function()local ok,err=mod.handle.confirm(page.id);self.notice=ok and ('Confirmed and saved'..(err and '; '..tostring(err) or '')) or tostring(err)end)

                hit(1310,81,135,29,function()mod.handle.discard(page.id);self.notice='Pending edits discarded'end)

            end

            local rows=selectable(page);self.row=math.max(1,math.min(self.row,#rows));local selected=rows[self.row]

            local wide=type(page.render_preview)~='function' or page.preview_popout
            for _,control in ipairs(page.controls)do if control.column then wide=false end end
            local settings_x=self.sidebar_width+35
            local available=1475-settings_x
            local row_width=wide and available or available/2-30
            local display={};local selected_at=1;local ordinal=0
            for _,control in ipairs(visible_controls(page))do
                if control.collapsible or (control.type~='text' and control.type~='section')then ordinal=ordinal+1 end
                if control==selected then selected_at=#display+1 end
                if control.type=='text' and control.text_role~='title' and control.text_role~='selection'then
                    for _,line in ipairs(M.rich(control.label,row_width*s,20*s,measure))do
                        local parts={};for _,span in ipairs(line.spans)do parts[#parts+1]=span.text end
                        display[#display+1]={control=control,label=table.concat(parts),body=true,row=ordinal}
                    end
                else display[#display+1]={control=control,label=control.label or '',row=ordinal}end
            end
            self.display_total=#display
            if not manual_scroll and selected and selected_at<=self.scroll then self.scroll=selected_at-1 end
            if not manual_scroll and selected and selected_at>self.scroll+12 then self.scroll=selected_at-12 end
            self.scroll=math.max(0,math.min(self.scroll,math.max(0,#display-12)))
            local columns={0,0}
            for i,entry in ipairs(display)do
                local c=entry.control

                if i>self.scroll and i<=self.scroll+12 then

                    local col=c.column or 1;columns[col]=columns[col]+1

                    local x=settings_x+(col-1)*(available/2);local y=623-(columns[col]-1)*38;local row_index=entry.row

                    if c==selected then rect(x-5,y-7,row_width+5,34,{48,58,65});rect(x-5,y-7,3,34,accent)end

                    local color=c.disabled and muted or accent

                    local informational=c.type=='text' or c.type=='section'

                    local label=string.rep('  ',c.depth or 0)..(c.collapsible and (section_open(page,c) and 'v ' or '> ') or '')..entry.label

                    local value_label,value_width
                    if c.type=='choice' or c.type=='button' then
                        local current=(mod.handle.preview or mod.handle.get)(c.id)
                        value_label=c.type=='choice' and tostring(c.choices[current]) or (c.button_label or c.label or 'Activate')
                        local presentation=c.presentation or 'combined'
                        local arrows=c.type=='choice' and presentation~='dropdown' and 60 or 0
                        local padding=c.type=='button' and 24 or (presentation=='selector' and 20 or 55)
                        local minimum=c.type=='button' and 175 or (presentation=='dropdown' and 280 or 220)
                        -- Width budgets are logical units; native measurements are pixels.
                        value_width=M.control_width(value_label,minimum*s,math.max(0,row_width-12-arrows)*s,padding*s,18*s,measure)/s
                    end
                    local reserved=value_width and (value_width+(c.type=='choice' and (c.presentation or 'combined')~='dropdown' and 60 or 0)+12) or 290
                    local label_width=informational and row_width or math.max(0,row_width-reserved)

                    if entry.body then text(x,y,label,20,c.disabled and muted or white)else bounded(x,y,label,20,c.disabled and muted or (c.type=='section' and accent or white),label_width) end

                    if c.collapsible then
                        local header=c
                        hit(x-5,y-7,row_width+5,34,function()self.row=row_index;self.focus='settings';change(header,0)end)
                    end
                    if c.type~='text' and c.type~='section' then

                        local value=(mod.handle.preview or mod.handle.get)(c.id);local control=c;local owner=mod

                        local vx=x+row_width-525

                        local function select()self.row=row_index;self.focus='settings'end

                        hit(x-5,y-7,row_width+5,34,function()select()end)

                        if c.type=='slider' then

                            if drag and drag.mod==mod and drag.control==c then value=drag.value end

                            local track=vx+245;local width=180;local fraction=math.max(0,math.min(1,(value-c.min)/(c.max-c.min)))

                            -- Cyan sliders are distinct from gold choice selectors.
                            local slider_fill=c.disabled and {103,118,123} or {64,203,215}
                            local slider_thumb=c.disabled and {137,148,151} or (c==selected and {196,251,255} or {115,231,240})
                            rect(track,y+4,width,7,c.disabled and {51,59,64} or {31,76,84})
                            rect(track,y+5,width*fraction,5,slider_fill)
                            rect(track+width*fraction-7,y-3,14,21,c.disabled and {64,74,80} or {17,56,65})
                            rect(track+width*fraction-5,y-1,10,17,slider_thumb)

                            local editing=self.text_edit and self.text_edit.mod==mod and self.text_edit.control==c

                            rect(vx+435,y-5,90,29,c.disabled and {35,42,48} or (editing and {31,76,84} or (c==selected and {115,231,240} or {24,56,64})))

                            local display=editing and self.text_edit.text..'|' or string.format('%.3f',value):gsub('0+$',''):gsub('%.$','')

                            bounded(vx+440,y,display,18,c.disabled and muted or (editing and {196,251,255} or (c==selected and selection_text or {168,238,243})),80)

                            hit(vx+435,y-5,90,29,function()

                                if control.disabled then return end;select()

                                self.text_edit={mod=owner,control=control,text=tostring((owner.handle.preview or owner.handle.get)(control.id)),replace=true}

                                self.notice='Type value; Enter saves, Escape cancels'

                            end)

                            hit(track-8,y-7,width+16,34,function(mx)

                                if control.disabled then return end;select()

                                local d={mod=owner,control=control,value=(owner.handle.preview or owner.handle.get)(control.id)}

                                function d.move(px)

                                    local f=math.max(0,math.min(1,(px-(ox+track*s))/(width*s)))

                                    d.value=math.min(control.max,control.min+math.floor(f*(control.max-control.min)/control.step+.5)*control.step)

                                end

                                drag=d;d.move(mx)

                            end)

                        elseif c.type=='input' then

                            local editing=self.text_edit and self.text_edit.control==c

                            hit(vx+275,y-5,250,29,function()select();change(control,0)end)

                            rect(vx+275,y-5,250,29,not c.disabled and c==selected and accent or {35,42,48})

                            bounded(vx+285,y,editing and self.text_edit.text..'|' or value,18,c.disabled and muted or (c==selected and selection_text or white),230)

                        elseif c.type=='color' then

                            rect(vx+300,y-3,34,23,api.color_rgb(value));rect(vx+350,y-5,175,29,c==selected and accent or {35,42,48});bounded(vx+360,y,value,18,c==selected and selection_text or white,155)

                            hit(vx+295,y-7,230,34,function()if control.disabled then return end;select();self.color_picker={mod=owner,control=control,rgb=api.color_rgb((owner.handle.preview or owner.handle.get)(control.id))}end)

                        elseif c.type=='toggle' then

                            hit(vx+350,y-5,175,29,function()select();change(control,0)end)

                            rect(vx+350,y-5,175,29,not c.disabled and c==selected and accent or {24,30,35})

                            rect(vx+354,y-1,36,21,{65,73,80});if value then rect(vx+358,y+3,28,13,white)end

                            text(vx+405,y,c.disabled and 'UNAVAILABLE' or (value and 'ON' or 'OFF'),c.disabled and 14 or 19,c.disabled and muted or (c==selected and selection_text or white))

                        elseif c.type=='choice' then

                            local presentation=c.presentation or 'combined'

                            local chosen=c.disabled and muted or (c==selected and {35,27,10} or {255,226,137})
                            local symbol=c.disabled and muted or {35,27,10}
                            local value_bg=c.disabled and {35,42,48} or (c==selected and {255,225,120} or {79,62,28})
                            local arrow_bg=c.disabled and {65,73,80} or {216,166,49}

                            local cw=value_width
                            local cx=vx+525-(presentation~='dropdown' and 30 or 0)-cw

                            if presentation~='dropdown' then

                                rect(cx-30,y-5,27,29,arrow_bg);text(cx-23,y,'<',18,symbol)

                                rect(cx+cw+3,y-5,27,29,arrow_bg);text(cx+cw+10,y,'>',18,symbol)

                                hit(cx-30,y-5,27,29,function()select();change(control,-1)end)

                                hit(cx+cw+3,y-5,27,29,function()select();change(control,1)end)

                            end

                            if c==selected and not c.disabled then rect(cx-2,y-7,cw+4,33,{110,77,18})end
                            rect(cx,y-5,cw,29,value_bg)

                            bounded(cx+9,y,tostring(c.choices[value]),18,chosen,cw-(presentation=='selector' and 20 or 55))

                            if presentation~='selector' then

                                -- Reserve an opaque indicator cell above the value text.

                                rect(cx+cw-32,y-5,32,29,arrow_bg);text(cx+cw-20,y,'v',18,symbol)

                                hit(cx,y-5,cw,29,function()

                                    if control.disabled then return end;select()

                                    self.dropdown={mod=owner,control=control,selected=value,scroll=math.max(0,math.min(math.max(0,#control.choices-8),value-4)),x=cx,top=y-8,width=cw}

                                end)

                            end

                        else
                            local valid_key=c.type=='keybind' and type(value)=='number' and value==value and value%1==0 and value>=0 and value<=255
                            local label=c.type=='button' and (c.button_label or c.label or 'Activate') or (valid_key and (value==0 and 'BIND KEY' or 'VK '..tostring(value)) or 'UNAVAILABLE')
                            local bw=value_width or 175;local bx=vx+525-bw
                            hit(bx,y-5,bw,29,function()select();change(control,0)end)
                            if c==selected and not c.disabled then rect(bx-1,y-6,bw+2,31,accent)end
                            rect(bx,y-5,bw,29,c.disabled and {35,42,48} or (c==selected and {37,47,55} or {55,65,73}))
                            bounded(bx+12,y,label,18,c.disabled and muted or white,math.max(0,bw-24))

                        end

                    end

                end

            end

            scrollbar('settings',1480,196,456,#display,12,self.scroll)

            -- The scrollbar communicates position without debug row counts.

            if type(page.render_preview)=='function' and page.preview_popout then
                rect(1135,690,300,32,{55,63,70});text(1145,699,'OPEN HUD PREVIEW',17,accent)
                hit(1135,690,300,32,function()
                    self.window_x=0
                    self.preview_window={mod=mod,page=page,x=math.max(0,w-420*s),y=math.max(0,(h-450*s)/2)}
                end)
            elseif type(page.render_preview)=='function' then

                local ok,preview=pcall(page.render_preview,{x=ox+950*s,y=oy+285*s,w=460*s,h=350*s,scale=s})

                if ok and type(preview)=='table' then

                    for _,command in ipairs(preview)do command.layer=110;command.hud_preview=true;commands[#commands+1]=command end

                end

            end

            local help=selected and selected.description or mod.description

            local key=mod.id..'/'..page.id..'/'..tostring(help)

            if help_key~=key then self.help_scroll=0;help_key=key end

            local hx=self.sidebar_width+35;local hw=1460-hx

            local lines=M.rich(help,hw*s,18*s,measure);local visible=3

            self.help_scroll=math.min(self.help_scroll,math.max(0,#lines-visible))

            help_bounds={x=ox+hx*s,y=oy+126*s,w=hw*s,h=64*s,maximum=math.max(0,#lines-visible)}

            for index=self.help_scroll+1,math.min(#lines,self.help_scroll+visible)do

                local line=lines[index];local tx=hx;local ty=177-(index-self.help_scroll-1)*22

                for _,span in ipairs(line.spans)do text(tx,ty,span.text,line.size/s,span.style=='plain' and muted or (span.style=='emphasis' and white or accent));tx=tx+span.width/s end

            end

            scrollbar('help',1470,126,64,#lines,visible,self.help_scroll)

        end

        hit(self.sidebar_width-6,196,12,510,function()split_drag={ox=ox,scale=s}end)

        rect(0,0,1500,55,{18,23,27})
        rect(0,55,1500,1,{110,88,35})
        bounded(25,32,'F10 / Esc Close   Tab Focus   Arrows Navigate / Change   Enter Select   Home Default   PgUp / PgDn Sections',14,muted,1120)
        bounded(1180,32,'github.com/HWG90',16,{255,225,120},295)
        -- A readable URL; no external browser is opened by menu rendering.

        -- Show the actual status, not a fixed character slice of a Lua error.

        local notice=self.notice:gsub('[%w_./\\-]+%.lua:%d+:%s*','')

        local lines,line={},''

        for word in notice:gmatch('%S+')do

            if #line>0 and #line+#word+1>58 then lines[#lines+1]=line;line=word

            else line=#line==0 and word or line..' '..word end

        end

        if #line>0 then lines[#lines+1]=line end

        if #notice>0 then bounded(25,64,notice,15,accent,1450)end

        if self.dropdown then

            local overlay_start=#commands+1

            local d=self.dropdown;local count=math.min(8,#d.control.choices);local height=count*31+8

            local top=math.max(height+8,math.min(752,d.top));local x=d.x;local dw=d.width or 250

            -- Overlay hit regions take priority and consume outside clicks.

            hit(-ox/s,-oy/s,w/s,h/s,function()self.dropdown=nil end)

            rect(x-2,top-height-2,dw+4,height+4,accent);rect(x,top-height,dw,height,{24,30,35})

            for index=d.scroll+1,math.min(#d.control.choices,d.scroll+count)do

                local y=top-29-(index-d.scroll-1)*31;local choice=index

                if index==d.selected then rect(x+3,y-4,dw-16,30,accent)end

                bounded(x+8,y,tostring(d.control.choices[index]),18,index==d.selected and selection_text or white,math.max(0,dw-24))

                hit(x+3,y-4,dw-16,30,function()

                    local ok,err=(d.mod.handle.edit or d.mod.handle.set)(d.control.id,choice)

                    self.notice=ok and (d.control.page and d.control.page.require_confirmation and 'Pending confirmation' or 'Saved') or tostring(err);self.dropdown=nil

                end)

            end

            scrollbar('dropdown',x+dw-7,top-height+4,height-8,#d.control.choices,count,d.scroll)

            for index=overlay_start,#commands do commands[index].popup=true;commands[index].layer=200 end

            if #d.control.choices>count then

                hit(x+dw-13,top-height,13,height,function(_,my)

                    local f=1-math.max(0,math.min(1,(my-(oy+(top-height)*s))/(height*s)))

                    d.scroll=math.floor(f*(#d.control.choices-count)+.5)

                end)

            end

        end

        local pv=self.preview_window
        if pv and api.mods[pv.mod.id]~=pv.mod then self.preview_window=nil;pv=nil end
        if pv then
            local pw,ph=420*s,450*s
            pv.x=math.max(0,math.min(w-pw,pv.x));pv.y=math.max(0,math.min(h-ph,pv.y))
            local px,py=pv.x,pv.y
            local first=#commands+1
            rect((px-ox)/s,(py-oy)/s,420,450,{20,25,30},.98)
            rect((px-ox)/s,(py-oy)/s+410,420,40,{35,42,48})
            text((px-ox)/s+14,(py-oy)/s+423,'HUD PREVIEW',18,accent)
            text((px-ox)/s+387,(py-oy)/s+422,'X',20,white)
            hit((px-ox)/s,(py-oy)/s,420,450,function()end)
            hit((px-ox)/s,(py-oy)/s+410,370,40,function(mx,my)
                preview_drag={dx=mx-px,dy=my-py,max_x=math.max(0,w-pw),max_y=math.max(0,h-ph)}
            end)
            hit((px-ox)/s+377,(py-oy)/s+410,43,40,function()self.preview_window=nil;preview_drag=nil end)
            local ok,preview=pcall(pv.page.render_preview,{x=px+20*s,y=py+35*s,w=380*s,h=345*s,scale=s})
            if ok and type(preview)=='table' then
                for _,command in ipairs(preview) do commands[#commands+1]=command end
            else text((px-ox)/s+15,(py-oy)/s+200,'Preview unavailable',18,muted) end
            text((px-ox)/s+14,(py-oy)/s+14,'Updates live with your settings',15,muted)
            for i=first,#commands do commands[i].hud_preview=true;commands[i].layer=110+(i-first)*0.01 end
        end

        if self.color_picker then

            local p=self.color_picker;local start=#commands+1;local px,py=p.x or 400,p.y or 195

            hit(-ox/s,-oy/s,w/s,h/s,function()self.color_picker=nil;self.text_edit=nil end)

            hit(px-2,py-2,704,434,function()end)

            hit(px,py+385,700,45,function(mx,my)color_drag={ox=ox,oy=oy,scale=s,dx=(mx-ox)/s-px,dy=(my-oy)/s-py}end)

            rect(px-2,py-2,704,434,accent);rect(px,py,700,430,{24,30,35})

            rect(px+650,py+389,32,30,{65,73,80});text(px+660,py+396,'X',20,white)

            hit(px+650,py+389,32,30,function()self.color_picker=nil;self.text_edit=nil end)

            text(px+20,py+397,'COLOR - RGB / HEX / SWATCHES',22,accent)

            local hue,saturation,brightness=api.rgb_hsv(p.rgb)

            p.hue=p.hue or hue;p.saturation=p.saturation or saturation;p.brightness=p.brightness or brightness

            for col=0,15 do for row=0,11 do

                rect(px+20+col*14,py+160+row*17,15,18,api.hsv_rgb(col/15,row/11,p.brightness))

            end end

            for row=0,15 do rect(px+262,py+160+row*12.75,25,13.75,api.hsv_rgb(p.hue,p.saturation,row/15))end

            rect(px+17+p.hue*224,py+157+p.saturation*204,6,6,white)

            rect(px+259,py+158+p.brightness*204,31,3,white)

            local function spectrum(mx,my)

                p.hue=math.max(0,math.min(1,((mx-ox)/s-px-20)/224))

                p.saturation=math.max(0,math.min(1,((my-oy)/s-py-160)/204));p.rgb=api.hsv_rgb(p.hue,p.saturation,p.brightness)

            end

            local function value_slider(mx,my)

                p.brightness=math.max(0,math.min(1,((my-oy)/s-py-160)/204));p.rgb=api.hsv_rgb(p.hue,p.saturation,p.brightness)

            end

            hit(px+20,py+160,224,204,function(mx,my)palette_drag=spectrum;spectrum(mx,my)end)

            hit(px+262,py+160,25,204,function(mx,my)palette_drag=value_slider;value_slider(mx,my)end)

            rect(px+595,py+287,85,65,p.rgb)

            local fields={{key=1,label='R',value=p.rgb[1]},{key=2,label='G',value=p.rgb[2]},{key=3,label='B',value=p.rgb[3]},{key='hex',label='HEX',value=api.color_hex(p.rgb)}}

            for index,field in ipairs(fields)do local fy=py+343-(index-1)*42

                text(px+315,fy,field.label,20,white);rect(px+370,fy-5,210,30,{55,63,70})

                local editing=self.text_edit and self.text_edit.color_channel==field.key

                text(px+380,fy,editing and self.text_edit.text..'|' or tostring(field.value),20,editing and accent or white)

                hit(px+370,fy-5,210,30,function()self.text_edit={color_channel=field.key,text=tostring(field.value):gsub('^#',''),replace=true}end)

            end

            text(px+20,py+126,'CUSTOM SWATCHES',17,muted)

            for index,hex in ipairs(api.swatches())do local sx=px+20+(index-1)*43

                if p.selected_swatch==index then rect(sx-3,py+76,41,36,accent)end

                rect(sx,py+79,35,30,api.color_rgb(hex))

                hit(sx,py+79,35,30,function()p.selected_swatch=index;p.rgb=api.color_rgb(hex);p.hue,p.saturation,p.brightness=api.rgb_hsv(p.rgb)end)

            end

            rect(px+550,py+78,130,32,{65,73,80});text(px+560,py+88,'SAVE SWATCH',16,accent)

            hit(px+550,py+78,130,32,function()local ok,err=api.save_swatch(p.rgb);self.notice=ok and 'Custom swatch saved' or tostring(err)end)

            rect(px+550,py+119,130,32,{65,73,80});text(px+557,py+129,'REPLACE',16,p.selected_swatch and accent or muted)

            hit(px+550,py+119,130,32,function()

                if not p.selected_swatch then self.notice='Select a saved swatch first';return end

                local ok,err=api.replace_swatch(p.selected_swatch,p.rgb);self.notice=ok and 'Selected swatch replaced' or tostring(err)

            end)

            rect(px+20,py+20,300,32,{65,73,80});text(px+35,py+29,'USE COLOR',18,accent)

            hit(px+20,py+20,300,32,function()self.commit_color()end)

            rect(px+370,py+20,310,32,{65,73,80});text(px+390,py+29,'CANCEL',18,white)

            hit(px+370,py+20,310,32,function()self.color_picker=nil;self.text_edit=nil end)

            for index=start,#commands do commands[index].popup=true;commands[index].layer=300 end

        end

        if self.dropdown then

            -- Popup primitives follow ordinary content and occupy a higher plane.

            for _,command in ipairs(commands)do if command.popup then command.layer=200 end end

        end

        text_age=visible_text_age

        return commands

    end

    return self

end

return M
