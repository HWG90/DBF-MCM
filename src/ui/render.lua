-- Stock GUI draw commands and corresponding hit regions.
local MODULE={}
function MODULE.install(context)
    local self,api,measure,console,state,M=context.self,context.api,context.measure,context.console,context.state,context.M
    local active,section_open,visible_controls,selectable,change,saved_notice=
        context.helpers.active,context.helpers.section_open,context.helpers.visible_controls,
        context.helpers.selectable,context.helpers.change,context.helpers.saved_notice
    function self.compose(w,h)

        if not self.visible then self.release_console();state.hits={};state.drag=nil;state.window_drag=nil;state.window_resize=nil;self.dropdown=nil;state.scroll_drag=nil;self.text_edit=nil;self.color_picker=nil;self.pointer_x,self.pointer_y=nil,nil;return {}end

        local commands={};state.hits={};state.choice_bounds={}
        local s=math.min(math.min(w/1920,h/1080)*math.max(.75,math.min(1.5,self.ui_scale or 1)),w/1100,h/600)
        local font_scale=math.max(.8,math.min(1.3,self.font_scale or 1))
        local ww=math.max(1100,math.min(w/s,self.window_width or self.default_window_width or 1500));local wh=math.max(600,math.min(h/s,self.window_height or self.default_window_height or 820))
        local ox,oy=math.max(0,math.min(w-ww*s,self.window_x or (w-ww*s)/2)),math.max(0,math.min(h-wh*s,self.window_y or (h-wh*s)/2))
        self.window_width,self.window_height=ww,wh
        self.window_bounds={x=ox,y=oy,w=ww*s,h=wh*s,scale=s}
        self.sidebar_width=math.max(250,math.min(self.sidebar_width,ww-700))
        local tree_visible=math.max(1,math.floor((wh-260)/31));local settings_visible=math.max(1,math.floor((wh-356)/42))
        self.tree_visible,self.settings_visible=tree_visible,settings_visible

        local visible_text_age={}

        self.window_x,self.window_y=ox,oy

        local T=M.palette;local white,muted,accent,selection_text=T.white,T.muted,T.brass,T.white
        local text_focus=false;local shape_layer=90
        local function hovering(x,y,rw,rh)
            return self.pointer_x and self.pointer_y and self.pointer_x>=ox+x*s and self.pointer_x<=ox+(x+rw)*s and self.pointer_y>=oy+y*s and self.pointer_y<=oy+(y+rh)*s
        end

        local function rect(x,y,rw,rh,color,a)commands[#commands+1]={type='rect',x=ox+x*s,y=oy+y*s,w=rw*s,h=rh*s,c=color,a=a or 1,layer=shape_layer}end

        local function text(x,y,value,size,color)

            commands[#commands+1]={type='text',x=ox+x*s,y=oy+y*s,text=tostring(value),size=(size or 20)*s*font_scale,c=color or white,a=1}

        end

        local function bounded(x,y,value,size,color,width)

            local key=tostring(value)..'|'..x..'|'..y..'|'..width

            local animate=text_focus or hovering(x,y-5,width,28)
            local age=state.text_age[key]
            if not age or age.active~=animate then age={start=state.elapsed,active=animate}end
            visible_text_age[key]=age
            local result=M.flow(value,width*s,size*s*font_scale,animate and (state.elapsed-age.start)or 0,measure)

            text(x,y,result,size,color);commands[#commands].full_text=tostring(value);commands[#commands].text_width=width*s

        end

        local function hit(x,y,rw,rh,fn)state.hits[#state.hits+1]={x=ox+x*s,y=oy+y*s,w=rw*s,h=rh*s,click=fn}end

        local function scrollbar(role,x,y,height,total,visible,offset)
            if total<=visible then return end
            local thumb=math.max(20,height*visible/total)
            local travel=height-thumb;local maximum=total-visible
            local progress=math.max(0,math.min(1,offset/maximum));local ty=y+travel*(1-progress)
            rect(x,y,4,height,T.line)
            rect(x-1,ty,6,thumb,hovering(x-7,y,18,height)and T.focus or T.border)
            commands[#commands].scrollbar=role
            local function set(value)
                value=math.max(0,math.min(maximum,math.floor(value+.5)))
                if role=='mods'then state.tree_scroll=value;state.tree_manual=true
                elseif role=='settings'then self.scroll=value;state.manual_scroll=true
                elseif role=='help'then self.help_scroll=value
                elseif role=='dropdown'and self.dropdown then self.dropdown.scroll=value end
            end
            hit(x-7,y,18,height,function(_,my)
                local local_y=(my-oy)/s
                local grab=local_y>=ty and local_y<=ty+thumb and local_y-ty or thumb/2
                state.scroll_drag={move=function(pointer_y)
                    local position=((pointer_y-oy)/s-grab-y)/travel
                    set((1-math.max(0,math.min(1,position)))*maximum)
                end}
                state.scroll_drag.move(my)
            end)
        end

        rect(0,0,ww,wh,T.border);rect(1,1,ww-2,wh-2,T.background,.99)
        rect(1,wh-61,ww-2,60,T.header);rect(1,wh-62,ww-2,1,T.line)
        rect(1,56,self.sidebar_width-1,wh-118,T.panel)
        rect(self.sidebar_width,56,1,wh-118,T.line)
        rect(18,wh-46,3,30,accent)
        rect(self.sidebar_width+20,126,ww-self.sidebar_width-40,68,T.panel)

        shape_layer=100
        hit(0,wh-60,ww,60,function(mx,my)

            if state.drag or self.capture then return end

            state.window_drag={dx=mx-ox,dy=my-oy,max_x=math.max(0,w-ww*s),max_y=math.max(0,h-wh*s)}

        end)

        state.wheel_bounds={x=ox,y=oy+196*s,w=ww*s,h=(wh-316)*s,split=ox+self.sidebar_width*s}

        local brand_width=measure and measure('DBF',23*s*font_scale)/s or 23*.62*3*font_scale
        local title_x=32+brand_width+18
        text(32,wh-39,'DBF',23,accent);text(title_x,wh-39,'MOD CONFIGURATION',23,white)
        local title_width=measure and measure('MOD CONFIGURATION',23*s*font_scale)/s or 23*.62*17*font_scale
        local settings_x=title_x+title_width+24
        local settings_size=18*s*font_scale
        local settings_glyph_width=M.control_width('Settings',0,math.huge,0,settings_size,measure)/s
        local settings_native_width=measure and measure('Settings',settings_size)/s or settings_glyph_width
        -- Native word kerning and the whole-glyph viewport can disagree; fit both.
        local settings_width=math.max(112,math.max(settings_glyph_width,settings_native_width)+26)
        rect(settings_x,wh-47,settings_width,34,hovering(settings_x,wh-47,settings_width,34)and T.field_hover or T.field)
        commands[#commands].ui_role='settings_button'
        bounded(settings_x+12,wh-38,'Settings',18,white,settings_width-24)
        hit(settings_x,wh-47,settings_width,34,function()local ok,reason=self.open_settings();if not ok then self.notice=reason end end)

        rect(ww-55,wh-45,38,30,hovering(ww-55,wh-45,38,30)and T.field_hover or T.field);text(ww-43,wh-38,'X',20,white)

        hit(ww-55,wh-45,38,30,function()self.visible=false;self.capture=false;self.dropdown=nil;state.scroll_drag=nil;self.text_edit=nil;self.color_picker=nil end)

        text(25,wh-105,'INSTALLED MODS',15,muted)

        local mods=api.list();local mod,page=active();text(self.sidebar_width-53,wh-105,tostring(#mods),15,muted)

        local sidebar=self.sidebar();state.tree_max=math.max(0,#sidebar-tree_visible);state.tree_scroll=math.max(0,math.min(state.tree_scroll,state.tree_max))

        if not state.tree_manual then

            for i,node in ipairs(sidebar)do if node.kind=='mod' and node.index==self.selected then

                if i<=state.tree_scroll then state.tree_scroll=i-1 elseif i>state.tree_scroll+tree_visible then state.tree_scroll=i-tree_visible end

            end end

        end

        self.mod_scroll=state.tree_scroll

        for i=state.tree_scroll+1,math.min(#sidebar,state.tree_scroll+tree_visible)do

            local entry=sidebar[i];local y=wh-149-(i-state.tree_scroll-1)*31;local x=25+entry.depth*16

            if entry.kind=='mod' then

                local selected=entry.index==self.selected

                rect(15,y-6,self.sidebar_width-30,30,selected and T.selected or (hovering(15,y-6,self.sidebar_width-30,30)and T.hover or T.panel));commands[#commands].layer=96
                rect(15,y-6,2,30,selected and accent or T.panel)

                text(x,y,entry.open and 'v' or '>',20,selected and white or muted)
                bounded(x+24,y,entry.mod.name,20,selected and white or muted,math.max(0,self.sidebar_width-39-x))

                hit(15,y-6,self.sidebar_width-30,30,function()

                    self.selected=entry.index;state.tree_expanded[entry.mod.id]=not entry.open;self.page=1;self.row=1;self.scroll=0;self.focus='settings';state.tree_manual=true

                end)

            else

                local last=true

                for next_index=i+1,#sidebar do

                    local next_entry=sidebar[next_index]

                    if next_entry.mod~=entry.mod or next_entry.depth<entry.depth then break end

                    if next_entry.depth==entry.depth then last=false;break end

                end

                for ancestor_depth=1,entry.depth-1 do
                    for next_index=i+1,#sidebar do
                        local next_entry=sidebar[next_index]
                        if next_entry.mod~=entry.mod or next_entry.depth<ancestor_depth then break end
                        if next_entry.depth==ancestor_depth then
                            rect(25+ancestor_depth*16-10,y-7,1,31,muted)
                            break
                        end
                    end
                end
                rect(x-10,last and y+6 or y-7,1,last and 18 or 31,muted)

                commands[#commands].tree_branch={last=last,row_y=oy+y*s,junction=oy+(y+6)*s}

                rect(x-10,y+6,9,1,muted)

                if entry.kind=='category' then

                    rect(x-4,y-6,self.sidebar_width-15-x+4,30,hovering(15,y-6,self.sidebar_width-30,30)and T.hover or T.panel);commands[#commands].layer=96
                    rect(x-4,y-6,1,30,T.line)
                    text(x+5,y,entry.open and 'v' or '>',20,accent)
                    bounded(x+29,y,entry.category.name,20,accent,math.max(0,self.sidebar_width-44-x))

                    hit(15,y-6,self.sidebar_width-30,30,function()state.expanded[entry.key]=not entry.open;state.tree_manual=true end)

                else

                    local selected=entry.mod_index==self.selected and entry.index==self.page

                    rect(x-4,y-6,self.sidebar_width-15-x+4,30,selected and T.selected or (hovering(15,y-6,self.sidebar_width-30,30)and T.hover or T.panel));commands[#commands].layer=96
                    rect(x-4,y-6,3,30,selected and accent or T.line)
                    bounded(x+5,y,entry.page.name,20,selected and accent or white,math.max(0,self.sidebar_width-20-x))

                    hit(15,y-6,self.sidebar_width-30,30,function()self.selected=entry.mod_index;self.page=entry.index;self.row=1;self.scroll=0;state.manual_scroll=false;self.focus='settings';state.tree_manual=true end)

                end

            end

        end

        scrollbar('mods',self.sidebar_width-10,140,wh-262,#sidebar,tree_visible,state.tree_scroll)

        if not mod then text(self.sidebar_width+35,wh-150,'No mods registered. See the author example.',24)

        else

            bounded(self.sidebar_width+35,wh-107,mod.name,16,muted,ww-55-self.sidebar_width);bounded(self.sidebar_width+35,wh-146,page.name,29,white,ww-55-self.sidebar_width)
            rect(self.sidebar_width+35,wh-162,ww-self.sidebar_width-65,1,T.line)

            -- Sections are named in the sidebar; no redundant ordinal footer.

            if next(page.pending) or next(page.actions) then

                local pending=0;for _ in pairs(page.pending)do pending=pending+1 end;for _ in pairs(page.actions)do pending=pending+1 end

                text(self.sidebar_width+35,91,pending..(pending==1 and ' change ready to apply' or ' changes ready to apply'),16,accent)

                rect(ww-340,79,135,34,accent);text(ww-319,89,'APPLY',18,T.background)

                rect(ww-190,79,135,34,hovering(ww-190,79,135,34)and T.field_hover or T.field);text(ww-176,89,'DISCARD',18,white)

                hit(ww-340,79,135,34,function()local ok,err=mod.handle.confirm(page.id);self.notice=ok and ('Confirmed and saved'..(err and '; '..tostring(err) or '')) or tostring(err)end)

                hit(ww-190,79,135,34,function()mod.handle.discard(page.id);self.notice='Pending edits discarded'end)

            end

            local rows=selectable(page);self.row=math.max(1,math.min(self.row,#rows));local selected=rows[self.row]
            local resettable=selected and selected.default~=nil and not selected.disabled
            rect(20,79,self.sidebar_width-40,34,resettable and T.field or T.panel)
            bounded(32,89,'RESET SETTING',16,resettable and white or T.disabled,self.sidebar_width-64)
            hit(20,79,self.sidebar_width-40,34,function()
                if not resettable then return end
                local called,ok,reason=pcall(mod.handle.edit or mod.handle.set,selected.id,selected.default)
                self.notice=called and ok and ('Default restored; '..saved_notice(selected,mod.handle))or tostring(called and reason or ok)
            end)

            local compact=ww-self.sidebar_width<1135
            local preview_popout=page.preview_popout or compact
            local wide=type(page.render_preview)~='function' or preview_popout
            for _,control in ipairs(page.controls)do if control.column and not compact then wide=false end end
            local settings_x=self.sidebar_width+35
            local available=ww-25-settings_x
            local row_width=wide and available or available/2-30
            local display={};local selected_at=1;local ordinal=0
            for _,control in ipairs(visible_controls(page))do
                if control.collapsible or (control.type~='text' and control.type~='section')then ordinal=ordinal+1 end
                if control==selected then selected_at=#display+1 end
                if control.type=='text' and control.text_role~='title' and control.text_role~='selection'then
                    for _,line in ipairs(M.rich(control.label,row_width*s,20*s*font_scale,measure))do
                        local parts={};for _,span in ipairs(line.spans)do parts[#parts+1]=span.text end
                        display[#display+1]={control=control,label=table.concat(parts),body=true,row=ordinal}
                    end
                else display[#display+1]={control=control,label=control.label or '',row=ordinal}end
            end
            self.display_total=#display
            if not state.manual_scroll and selected and selected_at<=self.scroll then self.scroll=selected_at-1 end
            if not state.manual_scroll and selected and selected_at>self.scroll+settings_visible then self.scroll=selected_at-settings_visible end
            self.scroll=math.max(0,math.min(self.scroll,math.max(0,#display-settings_visible)))
            local columns={0,0}
            for i,entry in ipairs(display)do
                local c=entry.control

                if i>self.scroll and i<=self.scroll+settings_visible then

                    local col=compact and 1 or (c.column or 1);columns[col]=columns[col]+1

                    local x=settings_x+(col-1)*(available/2);local y=wh-197-(columns[col]-1)*42;local row_index=entry.row

                    local row_hover=not self.dropdown and not self.color_picker and hovering(x-5,y-7,row_width+5,34)
                    text_focus=c==selected and self.focus=='settings'
                    rect(x-5,y-7,row_width+5,34,c==selected and T.selected or (row_hover and T.hover or ((i%2==0)and T.panel or T.background)))
                    commands[#commands].layer=95;commands[#commands].ui_role='setting_row';commands[#commands].hovered=row_hover==true;commands[#commands].focused=text_focus
                    rect(x-5,y-7,2,34,c==selected and (text_focus and T.focus or T.border)or T.background);commands[#commands].layer=99

                    local color=c.disabled and T.disabled or accent

                    local informational=c.type=='text' or c.type=='section'

                    local label=string.rep('  ',c.depth or 0)..(c.collapsible and (section_open(page,c) and 'v ' or '> ') or '')..entry.label

                    local value_label,value_width
                    if c.type=='choice' or c.type=='button' then
                        local selected_value=(mod.handle.preview or mod.handle.get)(c.id)
                        value_label=c.type=='choice' and tostring(c.choices[selected_value]) or (c.button_label or c.label or 'Activate')
                        local presentation=c.presentation or 'combined'
                        local arrows=c.type=='choice' and presentation~='dropdown' and 60 or 0
                        local padding=c.type=='button' and 24 or (presentation=='selector' and 20 or 55)
                        local minimum=c.type=='button' and 175 or (presentation=='dropdown' and 280 or 220)
                        -- Width budgets are logical units; native measurements are pixels.
                        value_width=M.control_width(value_label,minimum*s,math.max(0,row_width-12-arrows)*s,padding*s,18*s*font_scale,measure)/s
                    end
                    local reserved=value_width and (value_width+(c.type=='choice' and (c.presentation or 'combined')~='dropdown' and 60 or 0)+12) or 290
                    local label_width=informational and row_width or math.max(0,row_width-reserved)

                    if c.type=='text'and type(c.swatches)=='table'then
                        if c.swatch_label then bounded(x,y,label,20,white,math.max(40,row_width-110))end
                        local count=math.min(8,#c.swatches);local size=math.max(12,math.min(34,(row_width-12)/math.max(1,count)-8))
                        for slot=1,count do local swatch=c.swatches[slot];local color=swatch.rgb
                            if type(color)=='table'and #color==3 then
                                local rgb={};for ch=1,3 do rgb[ch]=math.max(0,math.min(255,tonumber(color[ch])or 0))end
                                local sx=c.swatch_label and x+row_width-100+(slot-1)*(size+8)or x+(slot-1)*(size+8)
                                rect(sx,y-4,size,size,rgb)
                                text(sx+3,y+3,tostring(swatch.row or slot),14,{255,255,255})
                                if swatch.control and swatch.owner and swatch.prepare then
                                    local item=swatch
                                    hit(sx,y-4,size,size,function()
                                        item.prepare();if item.control.disabled then return end
                                        self.row=row_index;self.focus='settings'
                                        self.color_picker={mod=item.owner,control=item.control,rgb=api.color_rgb((item.owner.handle.preview or item.owner.handle.get)(item.control.id))}
                                    end)
                                end
                            end
                        end
                    elseif entry.body then text(x,y,label,20,c.disabled and muted or white)
                    else
                        local heading=c.type=='section' or c.text_role=='title'
                        bounded(x,y,label,heading and 17 or 20,c.disabled and T.disabled or (heading and accent or white),label_width)
                    end

                    if c.collapsible then
                        local header=c
                        hit(x-5,y-7,row_width+5,34,function()self.row=row_index;self.focus='settings';change(header,0)end)
                    end
                    if c.type~='text' and c.type~='section' then

                        local value=(mod.handle.preview or mod.handle.get)(c.id);local control=c;local owner=mod

                        local vx=x+row_width-525

                        local function select()self.row=row_index;self.focus='settings'end

                        hit(x-5,y-7,row_width+5,34,function()select();if control.type=='toggle'and not control.disabled then change(control,0)end end)

                        if c.type=='slider' then

                            if state.drag and state.drag.mod==mod and state.drag.control==c then value=state.drag.value end

                            local track=vx+245;local width=180;local fraction=math.max(0,math.min(1,(value-c.min)/(c.max-c.min)))

                            -- Cyan sliders are distinct from gold choice selectors.
                            local slider_fill=c.disabled and T.disabled or T.focus
                            local slider_thumb=c.disabled and {137,148,151} or (c==selected and {196,251,255} or {115,231,240})
                            rect(track,y+4,width,7,c.disabled and {51,59,64} or {31,76,84})
                            rect(track,y+5,width*fraction,5,slider_fill)
                            rect(track+width*fraction-7,y-3,14,21,c.disabled and {64,74,80} or {17,56,65})
                            rect(track+width*fraction-5,y-1,10,17,slider_thumb)

                            local editing=self.text_edit and self.text_edit.mod==mod and self.text_edit.control==c

                            rect(vx+435,y-5,90,29,editing and T.field_hover or T.field)
                            rect(vx+435,y-5,90,1,editing and T.focus or T.border)

                            local display=editing and self.text_edit.text..'|' or string.format('%.3f',value):gsub('0+$',''):gsub('%.$','')

                            bounded(vx+440,y,display,18,c.disabled and T.disabled or white,80)

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

                                state.drag=d;d.move(mx)

                            end)

                        elseif c.type=='input' then

                            local editing=self.text_edit and self.text_edit.control==c

                            hit(vx+275,y-5,250,29,function()select();change(control,0)end)

                            rect(vx+275,y-5,250,29,not c.disabled and editing and T.field_hover or T.field)

                            bounded(vx+285,y,editing and self.text_edit.text..'|' or value,18,c.disabled and T.disabled or white,230)

                        elseif c.type=='color' then

                            rect(vx+300,y-3,34,23,api.color_rgb(value));rect(vx+350,y-5,175,29,T.field);bounded(vx+360,y,value,18,c==selected and white or muted,155)

                            hit(vx+295,y-7,230,34,function()if control.disabled then return end;select();self.color_picker={mod=owner,control=control,rgb=api.color_rgb((owner.handle.preview or owner.handle.get)(control.id))}end)

                        elseif c.type=='toggle' then

                            hit(vx+350,y-5,175,29,function()select();change(control,0)end)

                            rect(vx+350,y-5,175,29,T.field)

                            rect(vx+354,y-1,36,21,c.disabled and T.line or (value and {42,82,72}or T.border));rect(vx+(value and 374 or 356),y+2,14,15,c.disabled and T.disabled or (value and T.enabled or muted))

                            text(vx+405,y,c.disabled and 'DISABLED' or (value and 'ON' or 'OFF'),c.disabled and 14 or 19,c.disabled and T.disabled or (value and T.enabled or muted))

                        elseif c.type=='choice' then

                            local presentation=c.presentation or 'combined'

                            local chosen=c.disabled and T.disabled or white
                            local symbol=c.disabled and T.disabled or muted
                            local value_bg=T.field
                            local arrow_bg=c.disabled and T.line or T.field_hover

                            local cw=value_width
                            local cx=vx+525-(presentation~='dropdown' and 30 or 0)-cw
                            state.choice_bounds[c]={x=cx,top=y-8,width=cw}

                            if presentation~='dropdown' then

                                rect(cx-30,y-5,27,29,arrow_bg);text(cx-23,y,'<',18,symbol)

                                rect(cx+cw+3,y-5,27,29,arrow_bg);text(cx+cw+10,y,'>',18,symbol)

                                hit(cx-30,y-5,27,29,function()select();change(control,-1)end)

                                hit(cx+cw+3,y-5,27,29,function()select();change(control,1)end)

                            end

                            rect(cx-2,y-7,cw+4,33,c==selected and not c.disabled and T.border or T.line);commands[#commands].layer=99
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
                            local label=c.type=='button' and (c.button_label or c.label or 'Activate') or (valid_key and (value==0 and 'BIND KEY' or M.key_name(value)) or 'UNAVAILABLE')
                            local bw=value_width or 175;local bx=vx+525-bw
                            hit(bx,y-5,bw,29,function()select();change(control,0)end)
                            rect(bx-1,y-6,bw+2,31,c==selected and not c.disabled and T.border or T.line);commands[#commands].layer=99
                            rect(bx,y-5,bw,29,c.disabled and T.panel or (hovering(bx,y-5,bw,29)and T.field_hover or T.field))
                            bounded(bx+12,y,label,18,c.disabled and muted or white,math.max(0,bw-24))

                        end

                    end

                end

            end

            text_focus=false
            scrollbar('settings',ww-20,196,wh-364,#display,settings_visible,self.scroll)

            -- The scrollbar communicates position without debug row counts.

            if type(page.render_preview)=='function' and preview_popout then
                rect(ww-365,wh-130,300,32,{55,63,70});text(ww-355,wh-121,'OPEN HUD PREVIEW',17,accent)
                hit(ww-365,wh-130,300,32,function()
                    self.window_x=0
                    self.preview_window={mod=mod,page=page,x=math.max(0,w-420*s),y=math.max(0,(h-450*s)/2)}
                end)
            elseif type(page.render_preview)=='function' then

                local ok,preview=pcall(page.render_preview,{x=ox+(settings_x+available/2+15)*s,y=oy+220*s,w=(available/2-40)*s,h=(wh-470)*s,scale=s})

                if ok and type(preview)=='table' then

                    for _,command in ipairs(preview)do command.layer=110;command.hud_preview=true;commands[#commands+1]=command end

                end

            end

            local help=selected and selected.description or mod.description

            local key=mod.id..'/'..page.id..'/'..tostring(help)

            if state.help_key~=key then self.help_scroll=0;state.help_key=key end

            local hx=self.sidebar_width+35;local hw=ww-40-hx

            local line_height=math.ceil(22*font_scale)
            local lines=M.rich(help,hw*s,18*s*font_scale,measure);local visible=math.max(1,1+math.floor(51/line_height))

            self.help_scroll=math.min(self.help_scroll,math.max(0,#lines-visible))

            state.help_bounds={x=ox+hx*s,y=oy+126*s,w=hw*s,h=64*s,maximum=math.max(0,#lines-visible)}

            for index=self.help_scroll+1,math.min(#lines,self.help_scroll+visible)do

                local line=lines[index];local tx=hx;local ty=177-(index-self.help_scroll-1)*line_height

                for _,span in ipairs(line.spans)do text(tx,ty,span.text,line.size/(s*font_scale),span.style=='plain' and muted or (span.style=='emphasis' and white or accent));tx=tx+span.width/s end

            end

            scrollbar('help',ww-30,126,64,#lines,visible,self.help_scroll)

        end

        hit(self.sidebar_width-6,196,12,wh-310,function()state.split_drag={ox=ox,scale=s}end)

        rect(1,1,ww-2,54,T.panel)
        rect(1,55,ww-2,1,T.line)
        local shortcut=M.key_name(api.menu_toggle_key or 46)
        bounded(25,32,shortcut..' / Esc  Close     Tab  Focus     Arrows  Navigate     Enter  Edit',14,muted,ww-380)
        bounded(ww-260,32,'DBF MCM  /  '..tostring(api.version or ''),14,muted,235)
        -- Browser launch is an explicit Settings action, never a render side effect.

        -- Show the actual status, not a fixed character slice of a Lua error.

        local notice=self.notice:gsub('[%w_./\\-]+%.lua:%d+:%s*','')

        local lines,line={},''

        for word in notice:gmatch('%S+')do

            if #line>0 and #line+#word+1>58 then lines[#lines+1]=line;line=word

            else line=#line==0 and word or line..' '..word end

        end

        if #line>0 then lines[#lines+1]=line end

        if #notice>0 then bounded(self.sidebar_width+35,64,notice,15,muted,ww-self.sidebar_width-60)end

        local function resize_hit(edge,x,y,rw,rh)
            hit(x,y,rw,rh,function()
                if state.drag or self.capture then return end
                state.window_drag=nil;state.split_drag=nil
                state.window_resize={edge=edge,left=ox,right=ox+ww*s,bottom=oy,top=oy+wh*s,min_w=1100*s,min_h=600*s,screen_w=w,screen_h=h,scale=s}
            end)
        end
        resize_hit('w',0,14,6,wh-28);resize_hit('e',ww-6,14,6,wh-28)
        resize_hit('s',14,0,ww-28,6);resize_hit('n',14,wh-6,ww-28,6)
        for _,corner in ipairs({{'sw',0,0},{'se',ww-14,0},{'nw',0,wh-14},{'ne',ww-14,wh-14}})do
            resize_hit(corner[1],corner[2],corner[3],14,14)
            rect(corner[2]+4,corner[3]+4,6,6,muted);commands[#commands].resize_handle=corner[1]
        end
        if self.dropdown then

            local overlay_start=#commands+1

            local d=self.dropdown;local count=math.min(8,#d.control.choices);local height=count*31+8

            local top=math.max(height+8,math.min(wh-68,d.top));local dw=math.min(ww-16,d.width or 250);local x=math.max(8,math.min(ww-dw-8,d.x))

            -- Overlay hit regions take priority and consume outside clicks.

            hit(-ox/s,-oy/s,w/s,h/s,function()self.dropdown=nil;state.scroll_drag=nil end)

            rect(x-2,top-height-2,dw+4,height+4,T.border);rect(x,top-height,dw,height,T.panel)

            for index=d.scroll+1,math.min(#d.control.choices,d.scroll+count)do

                local y=top-29-(index-d.scroll-1)*31;local choice=index

                rect(x+3,y-4,dw-16,30,index==d.selected and T.selected or (hovering(x+3,y-4,dw-16,30)and T.hover or T.panel))
                rect(x+3,y-4,2,30,index==d.selected and accent or T.panel)

                text_focus=index==d.selected
                bounded(x+8,y,tostring(d.control.choices[index]),18,index==d.selected and white or muted,math.max(0,dw-24))

                hit(x+3,y-4,dw-16,30,function()

                    local ok,err=(d.mod.handle.edit or d.mod.handle.set)(d.control.id,choice)

                    self.notice=ok and (saved_notice(d.control,d.mod.handle)) or tostring(err);self.dropdown=nil;state.scroll_drag=nil

                end)

            end

            text_focus=false
            scrollbar('dropdown',x+dw-7,top-height+4,height-8,#d.control.choices,count,d.scroll)

            for index=overlay_start,#commands do commands[index].popup=true;commands[index].layer=200 end

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
                state.preview_drag={dx=mx-px,dy=my-py,max_x=math.max(0,w-pw),max_y=math.max(0,h-ph)}
            end)
            hit((px-ox)/s+377,(py-oy)/s+410,43,40,function()self.preview_window=nil;state.preview_drag=nil end)
            local ok,preview=pcall(pv.page.render_preview,{x=px+20*s,y=py+35*s,w=380*s,h=345*s,scale=s})
            if ok and type(preview)=='table' then
                for _,command in ipairs(preview) do commands[#commands+1]=command end
            else text((px-ox)/s+15,(py-oy)/s+200,'Preview unavailable',18,muted) end
            text((px-ox)/s+14,(py-oy)/s+14,'Updates live with your settings',15,muted)
            for i=first,#commands do commands[i].hud_preview=true;commands[i].layer=110+(i-first)*0.01 end
        end

        if self.color_picker then

            local p=self.color_picker;local start=#commands+1;local px,py=math.max(0,math.min(ww-704,p.x or 400)),math.max(0,math.min(wh-434,p.y or 195))

            hit(-ox/s,-oy/s,w/s,h/s,function()self.color_picker=nil;self.text_edit=nil end)

            hit(px-2,py-2,704,434,function()end)

            hit(px,py+385,700,45,function(mx,my)state.color_drag={ox=ox,oy=oy,scale=s,dx=(mx-ox)/s-px,dy=(my-oy)/s-py}end)

            rect(px-2,py-2,704,434,T.border);rect(px,py,700,430,T.panel);rect(px,py+385,700,45,T.header)

            rect(px+650,py+389,32,30,{65,73,80});text(px+660,py+396,'X',20,white)

            hit(px+650,py+389,32,30,function()self.color_picker=nil;self.text_edit=nil end)

            text(px+20,py+397,'COLOR',22,white)

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

            hit(px+20,py+160,224,204,function(mx,my)state.palette_drag=spectrum;spectrum(mx,my)end)

            hit(px+262,py+160,25,204,function(mx,my)state.palette_drag=value_slider;value_slider(mx,my)end)

            rect(px+595,py+287,85,65,p.rgb)

            local fields={{key=1,label='R',value=p.rgb[1]},{key=2,label='G',value=p.rgb[2]},{key=3,label='B',value=p.rgb[3]},{key='hex',label='HEX',value=api.color_hex(p.rgb)}}

            for index,field in ipairs(fields)do local fy=py+343-(index-1)*42

                text(px+315,fy,field.label,20,white);rect(px+370,fy-5,210,30,T.field)

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

            rect(px+550,py+78,130,32,{65,73,80});bounded(px+560,py+88,'SAVE SWATCH',16,accent,110)

            hit(px+550,py+78,130,32,function()local ok,err=api.save_swatch(p.rgb);self.notice=ok and 'Custom swatch saved' or tostring(err)end)

            rect(px+550,py+119,130,32,{65,73,80});text(px+557,py+129,'REPLACE',16,p.selected_swatch and accent or muted)

            hit(px+550,py+119,130,32,function()

                if not p.selected_swatch then self.notice='Select a saved swatch first';return end

                local ok,err=api.replace_swatch(p.selected_swatch,p.rgb);self.notice=ok and 'Selected swatch replaced' or tostring(err)

            end)

            rect(px+20,py+20,300,32,accent);text(px+35,py+29,'USE COLOR',18,T.background)

            hit(px+20,py+20,300,32,function()self.commit_color()end)

            rect(px+370,py+20,310,32,{65,73,80});text(px+390,py+29,'CANCEL',18,white)

            hit(px+370,py+20,310,32,function()self.color_picker=nil;self.text_edit=nil end)

            for index=start,#commands do commands[index].popup=true;commands[index].layer=300 end

        end

        if self.dropdown then

            -- Popup primitives follow ordinary content and occupy a higher plane.

            for _,command in ipairs(commands)do if command.popup then command.layer=200 end end

        end

        state.text_age=visible_text_age
        if console then for _,command in ipairs(console.compose(w,h,self.window_bounds,true))do commands[#commands+1]=command end end

        return commands

    end
end
return MODULE
