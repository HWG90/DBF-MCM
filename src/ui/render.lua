-- Stock GUI draw commands and corresponding hit regions.
local MODULE={}
function MODULE.install(context)
    local self,api,measure,console,state,M=context.self,context.api,context.measure,context.console,context.state,context.M
    local Layout,Branding=M.layout,M.branding
    local active,section_open,visible_controls,selectable,change,saved_notice=
        context.helpers.active,context.helpers.section_open,context.helpers.visible_controls,
        context.helpers.selectable,context.helpers.change,context.helpers.saved_notice
    function self.compose(w,h)

        if type(w)~='number'or type(h)~='number'or not(w>0 and h>0 and w<math.huge and h<math.huge)then return {}end
        if not self.visible then if self.finish_text_field then self.finish_text_field(true)end;self.release_console();state.hits={};state.drag=nil;state.window_drag=nil;state.window_resize=nil;self.dropdown=nil;self.context_menu=nil;state.scroll_drag=nil;self.text_edit=nil;self.color_picker=nil;self.pointer_x,self.pointer_y=nil,nil;return {}end

        local commands={};state.hits={};state.choice_bounds={}
        local s=math.min(math.min(w/1920,h/1080)*math.max(.75,math.min(1.5,self.ui_scale or 1)),w/1100,h/600)
        local font_scale=math.max(.8,math.min(1.3,self.font_scale or 1))
        local ww=math.max(1100,math.min(w/s,self.window_width or self.default_window_width or 1500));local wh=math.max(600,math.min(h/s,self.window_height or self.default_window_height or 820))
        local ox,oy=math.max(0,math.min(w-ww*s,self.window_x or (w-ww*s)/2)),math.max(0,math.min(h-wh*s,self.window_y or (h-wh*s)/2))
        self.window_width,self.window_height=ww,wh
        self.window_bounds={x=ox,y=oy,w=ww*s,h=wh*s,scale=s}
        self.sidebar_width=Layout.sidebar(self.sidebar_width,ww)
        local tree_visible=math.max(1,math.floor((wh-260)/31));local settings_visible=math.max(1,math.floor((wh-356)/Layout.row_step))
        self.tree_visible,self.settings_visible=tree_visible,settings_visible

        local visible_text_age={}

        self.window_x,self.window_y=ox,oy

        local T=M.palette;local white,muted,accent,selection_text=T.white,T.muted,T.focus,T.white
        local text_focus=false;local shape_layer=90;local surface_scope='main'
        local function hovering(x,y,rw,rh)
            if surface_scope=='main'and (self.dropdown or self.color_picker or self.context_menu)or surface_scope=='dropdown'and self.color_picker then return false end
            return self.pointer_x and self.pointer_y and self.pointer_x>=ox+x*s and self.pointer_x<=ox+(x+rw)*s and self.pointer_y>=oy+y*s and self.pointer_y<=oy+(y+rh)*s
        end

        local function rect(x,y,rw,rh,color,a,role)
            local offsets={control_border=1,window_frame=5,slider_track=2,slider_fill=3,slider_thumb=4,slider_thumb_ink=5,switch_track=2,switch_thumb=4,checkbox_box=2,checkbox_mark=4,widget_border=3}
            local offset=offsets[role]or 0
            commands[#commands+1]={type='rect',x=ox+x*s,y=oy+y*s,w=rw*s,h=rh*s,c=color,a=a or 1,layer=shape_layer+offset,ui_role=role,surface_offset=offset}
        end
        local function triangle(points,color,role)
            local p={};for index=1,#points,2 do p[index]=ox+points[index]*s;p[index+1]=oy+points[index+1]*s end
            local offset=role=='emblem'and 4 or role=='emblem_cutout'and 5 or role=='hazard'and 2 or 0
            commands[#commands+1]={type='triangle',points=p,c=color,a=1,layer=shape_layer+offset,ui_role=role,surface_offset=offset}
        end
        local function border(x,y,rw,rh,color,role)
            local stroke=math.min(2/s,rw/2,rh/2)
            role=role or 'control_border'
            rect(x,y,rw,stroke,color,nil,role);rect(x,y+rh-stroke,rw,stroke,color,nil,role)
            rect(x,y+stroke,stroke,math.max(0,rh-2*stroke),color,nil,role)
            rect(x+rw-stroke,y+stroke,stroke,math.max(0,rh-2*stroke),color,nil,role)
        end
        local function surface(x,y,rw,rh,options)
            local o=options or {};local enabled=o.enabled~=false
            local hover=enabled and hovering(x,y,rw,rh)
            local fill=not enabled and T.panel or o.primary and accent or (o.selected and not o.field and T.selected)
                or (hover and (o.field and T.field_hover or T.hover))or (o.field and T.field or T.panel)
            rect(x,y,rw,rh,fill,nil,'control_fill')
            local edge=not enabled and T.line or (o.primary or o.selected)and accent or hover and T.border_hover or T.border
            border(x,y,rw,rh,edge)
        end
        local function text_y(y,height,size,value,role)
            local resolved=M.text_size(size,role,font_scale)
            local low,high,optical=0,resolved,0
            if self.text_metrics then
                local ok,m=pcall(self.text_metrics,resolved*s,tostring(value or ''))
                if ok and type(m)=='table'and type(m.min_y)=='number'and type(m.max_y)=='number'and m.max_y>m.min_y and m.max_y-m.min_y<resolved*s*3 then
                    low,high=m.min_y/s,m.max_y/s
                    if type(m.optical_y)=='number'and math.abs(m.optical_y)<resolved*s then optical=m.optical_y/s end
                end
            end
            local baseline=y+(height-(high-low))/2-low+optical
            if height>=high-low+2 then baseline=math.max(y-low+1,math.min(y+height-high-1,baseline))end
            return baseline
        end

        local function text(x,y,value,size,color,role,fitted)

            local resolved,resolved_role=M.text_size(size,role,font_scale)
            commands[#commands+1]={type='text',x=ox+x*s,y=oy+y*s,text=tostring(value),size=(fitted and size or resolved)*s,c=color or white,a=1,
                layer=shape_layer+2,surface_offset=2,text_role=resolved_role,text_bold=resolved_role=='heading'or resolved_role=='title'}

        end

        local function bounded(x,y,value,size,color,width,focused,role,box_y,box_height)

            local key=tostring(value)..'|'..x..'|'..y..'|'..width..'|'..tostring(self.font_metric_key or '')

            local animate=focused or text_focus or hovering(x,y-5,width,28)
            local age=state.text_age[key]
            if not age or age.active~=animate then age={start=state.elapsed,active=animate}end
            visible_text_age[key]=age
            local resolved,resolved_role=M.text_size(size,role,font_scale)
            local ink_padding=(resolved_role=='heading'or resolved_role=='title')and .65 or 0
            local result=M.flow(value,math.max(0,width*s-ink_padding),resolved*s,animate and (state.elapsed-age.start)or 0,measure)

            text(x,box_y and text_y(box_y,box_height,size,result,role)or y,result,size,color,role)
            commands[#commands].full_text=tostring(value);commands[#commands].text_width=width*s
            if box_y then commands[#commands].text_bounds={x=ox+x*s,y=oy+box_y*s,w=width*s,h=box_height*s}end

        end

        local function hit(x,y,rw,rh,fn)state.hits[#state.hits+1]={x=ox+x*s,y=oy+y*s,w=rw*s,h=rh*s,click=fn}end
        local function right_target(target)
            state.hits[#state.hits].right_click=function(mx,my)return self.open_context(target,mx,my)end
        end

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

        rect(0,0,ww,wh,T.background,.99);border(0,0,ww,wh,T.border,'window_frame')
        rect(1,wh-61,ww-2,60,T.header);rect(1,wh-62,ww-2,1,T.line)
        rect(1,56,self.sidebar_width-1,wh-118,T.panel)
        rect(self.sidebar_width,56,1,wh-118,T.line)
        Branding.hazards(2,wh-11,ww-4,7,accent,triangle)
        Branding.skull(20,wh-43,64,accent,T.header,triangle)

        shape_layer=100
        hit(0,wh-60,ww,60,function(mx,my)

            if state.drag or self.capture then return end

            state.window_drag={dx=mx-ox,dy=my-oy,max_x=math.max(0,w-ww*s),max_y=math.max(0,h-wh*s)}

        end)

        state.wheel_bounds={x=ox,y=oy+196*s,w=ww*s,h=(wh-316)*s,split=ox+self.sidebar_width*s}

        local mods=api.list();local mod,page=active()
        local brand_width=measure and measure('DBF',23*s*font_scale)/s or 23*.62*3*font_scale
        local title_x=98+brand_width+18
        text(98,wh-39,'DBF',23,accent);text(title_x,wh-39,'MOD CONFIGURATION',23,white)
        local title_width=measure and measure('MOD CONFIGURATION',23*s*font_scale)/s or 23*.62*17*font_scale
        local settings_x=title_x+title_width+24
        local settings_size=M.text_size(18,nil,font_scale)*s
        local settings_glyph_width=M.control_width('Settings',0,math.huge,0,settings_size,measure)/s
        local settings_native_width=measure and measure('Settings',settings_size)/s or settings_glyph_width
        -- Native word kerning and the whole-glyph viewport can disagree; fit both.
        local settings_width=math.max(112,math.max(settings_glyph_width,settings_native_width)+26)
        surface(settings_x,wh-47,settings_width,34,{selected=mod and mod.id==api.settings_mod_id and page and page.id==api.settings_page_id})
        commands[#commands-4].ui_role='settings_button'
        bounded(settings_x+12,wh-38,'Settings',18,white,settings_width-24,nil,nil,wh-47,34)
        hit(settings_x,wh-47,settings_width,34,function()local ok,reason=self.open_settings();if not ok then self.notice=reason end end)
        if console then
            local console_x=settings_x+settings_width+12
            local console_width=math.max(104,M.control_width('Console',0,math.huge,24*s,settings_size,measure)/s)
            surface(console_x,wh-47,console_width,34)
            bounded(console_x+12,wh-38,'Console',18,white,console_width-24,nil,nil,wh-47,34)
            hit(console_x,wh-47,console_width,34,function()self.open_console()end)
        end

        surface(ww-55,wh-45,38,30);text(ww-43,text_y(wh-45,30,20,'X'),'X',20,white)

        hit(ww-55,wh-45,38,30,function()self.visible=false;self.capture=false;self.dropdown=nil;self.context_menu=nil;state.scroll_drag=nil;self.text_edit=nil;self.color_picker=nil end)

        bounded(25,wh-105,'INSTALLED MODS',15,muted,self.sidebar_width-95,nil,'hint')

        text(self.sidebar_width-53,wh-105,tostring(#mods),15,muted)

        local nav_text,nav_branch=T.nav_text or white,T.nav_branch or muted
        local nav_border,nav_hover=T.nav_border or T.border,T.field_hover or T.hover
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

                rect(15,y-6,self.sidebar_width-30,30,selected and T.selected or (hovering(15,y-6,self.sidebar_width-30,30)and nav_hover or T.nav_mod or T.header));commands[#commands].layer=96
                border(15,y-6,self.sidebar_width-30,30,nav_border)
                rect(15,y-6,2/s,30,selected and accent or nav_border)

                text(x,text_y(y-6,30,20,entry.open and 'v' or '>'),entry.open and 'v' or '>',20,selected and white or nav_text)
                bounded(x+24,y,entry.mod.name,20,selected and white or nav_text,math.max(0,self.sidebar_width-39-x),selected and self.focus=='mods',nil,y-6,30)

                hit(15,y-6,self.sidebar_width-30,30,function()

                    self.selected=entry.index;state.tree_expanded[entry.mod.id]=not entry.open;self.page=1;self.row=1;self.scroll=0;self.focus='settings';state.tree_manual=true

                end)
                right_target({kind='mod',mod=entry.mod})

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
                            rect(25+ancestor_depth*16-10,y-7,1,31,nav_branch)
                            break
                        end
                    end
                end
                rect(x-10,last and y+6 or y-7,1,last and 18 or 31,nav_branch)

                commands[#commands].tree_branch={last=last,row_y=oy+y*s,junction=oy+(y+6)*s}

                rect(x-10,y+6,9,1,nav_branch)

                if entry.kind=='category' then

                    rect(x-4,y-6,self.sidebar_width-15-x+4,30,hovering(15,y-6,self.sidebar_width-30,30)and nav_hover or T.nav_page or T.field);commands[#commands].layer=96
                    rect(x-4,y-6,self.sidebar_width-15-x+4,1/s,nav_border)
                    text(x+5,text_y(y-6,30,20,entry.open and 'v' or '>'),entry.open and 'v' or '>',20,nav_text)
                    bounded(x+29,y,entry.category.name,20,nav_text,math.max(0,self.sidebar_width-44-x),nil,nil,y-6,30)

                    hit(15,y-6,self.sidebar_width-30,30,function()state.expanded[entry.key]=not entry.open;state.tree_manual=true end)
                    right_target({kind='category',mod=entry.mod,key=entry.key,category=entry.category})

                else

                    local selected=entry.mod_index==self.selected and entry.index==self.page

                    rect(x-4,y-6,self.sidebar_width-15-x+4,30,selected and T.selected or (hovering(15,y-6,self.sidebar_width-30,30)and nav_hover or T.nav_page or T.field));commands[#commands].layer=96
                    rect(x-4,y-6,self.sidebar_width-15-x+4,1/s,nav_border)
                    rect(x-4,y-6,2/s,30,selected and accent or nav_border)
                    bounded(x+5,y,entry.page.name,20,selected and white or nav_text,math.max(0,self.sidebar_width-20-x),nil,nil,y-6,30)

                    hit(15,y-6,self.sidebar_width-30,30,function()self.selected=entry.mod_index;self.page=entry.index;self.row=1;self.scroll=0;state.manual_scroll=false;self.focus='settings';state.tree_manual=true end)
                    right_target({kind='page',mod=entry.mod,page=entry.page})

                end

            end

        end

        scrollbar('mods',self.sidebar_width-10,140,wh-262,#sidebar,tree_visible,state.tree_scroll)

        if not mod then text(self.sidebar_width+35,wh-150,'No mods registered. See the author example.',24)

        else

            bounded(self.sidebar_width+35,wh-107,mod.name,16,muted,ww-55-self.sidebar_width,nil,'hint',wh-115,28)
            bounded(self.sidebar_width+35,wh-146,page.name,29,white,ww-55-self.sidebar_width,nil,'title',wh-158,42)
            rect(self.sidebar_width+35,wh-162,ww-self.sidebar_width-65,1,T.line)

            -- Sections are named in the sidebar; no redundant ordinal footer.

            if next(page.pending) or next(page.actions) then

                local pending=0;for _ in pairs(page.pending)do pending=pending+1 end;for _ in pairs(page.actions)do pending=pending+1 end

                bounded(self.sidebar_width+35,91,pending..(pending==1 and ' change ready to apply' or ' changes ready to apply'),16,accent,math.max(0,ww-395-self.sidebar_width),nil,'hint',79,34)

                surface(ww-340,79,135,34,{primary=true});text(ww-319,text_y(79,34,18,'APPLY'),'APPLY',18,T.background)

                surface(ww-190,79,135,34);text(ww-176,text_y(79,34,18,'DISCARD'),'DISCARD',18,white)

                hit(ww-340,79,135,34,function()local ok,err=mod.handle.confirm(page.id);self.notice=ok and ('Confirmed and saved'..(err and '; '..tostring(err) or '')) or tostring(err)end)

                hit(ww-190,79,135,34,function()mod.handle.discard(page.id);self.notice='Pending edits discarded'end)

            end

            local rows=selectable(page);self.row=math.max(1,math.min(self.row,#rows));local selected=rows[self.row]
            local resettable=selected and selected.default~=nil and not selected.disabled
            surface(20,79,self.sidebar_width-40,34,{enabled=resettable})
            bounded(32,89,'RESET SETTING',16,resettable and white or T.disabled,self.sidebar_width-64,nil,'body',79,34)
            hit(20,79,self.sidebar_width-40,34,function()
                if not resettable then return end
                local called,ok,reason=pcall(mod.handle.edit or mod.handle.set,selected.id,selected.default)
                self.notice=called and ok and ('Default restored; '..saved_notice(selected,mod.handle))or tostring(called and reason or ok)
            end)

            local compact=ww-self.sidebar_width<1135
            local second_column=false;for _,control in ipairs(page.controls)do if control.column==2 then second_column=true end end
            local preview_popout=page.preview_popout or compact or second_column
            local wide=type(page.render_preview)~='function' or preview_popout
            for _,control in ipairs(page.controls)do if control.column and not compact then wide=false end end
            local settings_x=self.sidebar_width+35
            local available=ww-25-settings_x
            local lane_width=wide and available or available/2-Layout.column_gap
            local row_geometry=Layout.rows(lane_width,visible_controls(page),measure or function(value,size)return #value*size*.62 end,M.text_size(20,nil,font_scale),s)
            local row_width=row_geometry.width
            local inspector=wide and type(page.render_preview)~='function'and available-row_width>=300
            self.layout_geometry={row_width=row_width,control_offset=row_geometry.anchor,column_width=lane_width,inspector=inspector,scale=s}
            if inspector then
                settings_visible=math.max(1,math.floor((wh-286)/Layout.row_step));self.settings_visible=settings_visible
                state.wheel_bounds.y=oy+126*s;state.wheel_bounds.h=(wh-246)*s
            end
            local display={};local selected_at=1;local ordinal=0
            for _,control in ipairs(visible_controls(page))do
                if control.native_binding_id or control.collapsible or (control.type~='text' and control.type~='section')then ordinal=ordinal+1 end
                if control==selected then selected_at=#display+1 end
                if not control.native_binding_id and control.type=='text' and control.text_role~='title' and control.text_role~='selection'then
                    for _,line in ipairs(M.rich(control.label,row_width*s,20*s*font_scale,measure))do
                        local parts={};for _,span in ipairs(line.spans)do parts[#parts+1]=span.text end
                        display[#display+1]={control=control,label=table.concat(parts),body=true,row=ordinal}
                    end
                else display[#display+1]={control=control,label=control.label or '',row=ordinal}end
            end
            -- Both columns share a viewport offset, but each has its own row
            -- positions. Clipping a flat registration slice drops entire columns.
            local columns={0,0};local selected_column=1
            for _,entry in ipairs(display)do
                local col=compact and 1 or (entry.control.column or 1)
                columns[col]=columns[col]+1
                entry.column,entry.line=col,columns[col]
                if entry.control==selected then selected_at=entry.line;selected_column=col end
            end
            self.display_total=math.max(columns[1],columns[2])
            local function column_offset(col)
                -- A shorter column stops at its final viewport instead of
                -- disappearing while the other column continues scrolling.
                return math.min(self.scroll,math.max(0,columns[col]-settings_visible))
            end
            local selected_offset=column_offset(selected_column)
            if not state.manual_scroll and selected and selected_at<=selected_offset then self.scroll=selected_at-1 end
            if not state.manual_scroll and selected and selected_at>selected_offset+settings_visible then self.scroll=selected_at-settings_visible end
            self.scroll=math.max(0,math.min(self.scroll,math.max(0,self.display_total-settings_visible)))
            for i,entry in ipairs(display)do
                local c=entry.control
                local offset=column_offset(entry.column)

                if entry.line>offset and entry.line<=offset+settings_visible then

                    local col=entry.column

                    local x=settings_x+(col-1)*(available/2);local y=wh-197-(entry.line-offset-1)*Layout.row_step;local row_index=entry.row

                    local row_hover=not self.dropdown and not self.color_picker and hovering(x-5,y-7,row_width+5,34)
                    text_focus=c==selected and self.focus=='settings'
                    rect(x-5,y-7,row_width+5,34,c==selected and T.selected or (row_hover and T.hover or ((i%2==0)and T.panel or T.background)))
                    commands[#commands].layer=95;commands[#commands].ui_role='setting_row';commands[#commands].hovered=row_hover==true;commands[#commands].focused=text_focus
                    rect(x-5,y-7,2,34,c==selected and (text_focus and T.focus or T.border)or T.background);commands[#commands].layer=99

                    local color=c.disabled and T.disabled or accent

                    local informational=not c.native_binding_id and (c.type=='text' or c.type=='section')

                    local label=string.rep('  ',c.depth or 0)..(c.collapsible and (section_open(page,c) and 'v ' or '> ') or '')..entry.label

                    local value_label,value_width
                    if c.type=='choice' or c.type=='button' then
                        local selected_value=(mod.handle.preview or mod.handle.get)(c.id)
                        value_label=c.type=='choice' and tostring(c.choices[selected_value]) or (c.button_label or c.label or 'Activate')
                        local presentation=Layout.choice_presentation(c.presentation)
                        local arrows=c.type=='choice' and presentation=='selector' and 60 or 0
                        local padding=c.type=='button' and 24 or (presentation=='selector' and 20 or 55)
                        local minimum=c.type=='button' and 175 or (presentation=='dropdown' and 280 or 220)
                        -- Width budgets are logical units; native measurements are pixels.
                        -- Long values can scroll within their field; keep a
                        -- readable label alongside them even in two columns.
                        local value_budget=row_geometry.field_width-arrows
                        value_width=M.control_width(value_label,minimum*s,math.max(0,value_budget)*s,padding*s,M.text_size(18,nil,font_scale)*s,measure)/s
                    end
                    -- Labels and controls share a bounded starting edge.
                    local label_width=informational and row_width or row_geometry.label_width

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
                        bounded(x,y,label,heading and 17 or 20,c.disabled and T.disabled or white,label_width,nil,heading and 'heading'or 'body',y-7,34)
                    end

                    if c.collapsible then
                        local header=c
                        hit(x-5,y-7,row_width+5,34,function()self.row=row_index;self.focus='settings';change(header,0)end)
                        right_target({kind='control',mod=mod,page=page,control=c,row=row_index})
                    end
                    if c.native_binding_id then
                        local bx=x+row_geometry.anchor;local bw=row_geometry.field_width
                        local capturing=self.capture and self.capture.native_binding_id==c.native_binding_id and
                            self.capture.native_binding_bind==c.native_binding_bind
                        local value=capturing and 'Press a key' or c.native_binding_value or 'Unavailable'
                        surface(bx,y-5,bw,29,{field=true,selected=c==selected and self.focus=='settings'})
                        bounded(bx+12,y,value,18,white,math.max(0,bw-24),nil,'body',y-5,29)
                        commands[#commands].native_binding_id=c.native_binding_id
                        hit(x-5,y-7,row_width+5,34,function()
                            self.row=row_index;self.focus='settings';change(c,0)
                        end)
                    elseif c.type~='text' and c.type~='section' then

                        local value=(mod.handle.preview or mod.handle.get)(c.id);local control=c;local owner=mod

                        local field_x=x+row_geometry.anchor
                        local vx=field_x-350
                        if c.type=='slider'then vx=field_x-245
                        elseif c.type=='input'then vx=field_x-275
                        elseif c.type=='color'then vx=field_x-295
                        elseif c.type=='choice'then vx=field_x+(value_width or 0)+(Layout.choice_presentation(c.presentation)=='selector'and 60 or 0)-525
                        elseif c.type=='button'then vx=field_x+(value_width or 175)-525
                        end

                        local function select()self.row=row_index;self.focus='settings'end

                        hit(x-5,y-7,row_width+5,34,function()select();if control.type=='toggle'and not control.disabled then change(control,0)end end)
                        right_target({kind='control',mod=mod,page=page,control=c,row=row_index})

                        if c.type=='slider' then

                            if state.drag and state.drag.mod==mod and state.drag.control==c then value=state.drag.value end

                            local track=vx+245;local numeric_width=math.min(90,row_geometry.field_width*.3)
                            local width=math.max(70,math.min(180,row_geometry.field_width-numeric_width-14));local numeric_x=track+width+10
                            local fraction=math.max(0,math.min(1,(value-c.min)/(c.max-c.min)))

                            -- Neutral track, gold value and an ivory focused thumb.
                            local slider_fill=c.disabled and T.disabled or T.focus
                            local slider_thumb=c.disabled and T.disabled or (c==selected and T.white or T.focus)
                            rect(track,y+4,width,7,T.line,nil,'slider_track')
                            rect(track,y+5,width*fraction,5,slider_fill,nil,'slider_fill')
                            rect(track+width*fraction-7,y-3,14,21,T.border,nil,'slider_thumb')
                            rect(track+width*fraction-5,y-1,10,17,slider_thumb,nil,'slider_thumb_ink')

                            local editing=self.text_edit and self.text_edit.mod==mod and self.text_edit.control==c

                            surface(numeric_x,y-5,numeric_width,29,{enabled=not c.disabled,field=true,selected=editing})

                            local display=editing and self.text_edit.text..'|' or string.format('%.3f',value):gsub('0+$',''):gsub('%.$','')

                            bounded(numeric_x+5,y,display,18,c.disabled and T.disabled or white,numeric_width-10,nil,nil,y-5,29)

                            hit(numeric_x,y-5,numeric_width,29,function()

                                if control.disabled then return end;select()

                                self.text_edit={mod=owner,control=control,text=tostring((owner.handle.preview or owner.handle.get)(control.id)),replace=true}

                                self.notice='Type value; Enter saves, Escape cancels'

                            end)
                            state.hits[#state.hits].edit_control=control;state.hits[#state.hits].edit_mod=owner
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

                            local input_width=math.min(300,row_geometry.field_width)
                            hit(vx+275,y-5,input_width,29,function()select();change(control,0)end)

                            surface(vx+275,y-5,input_width,29,{enabled=not c.disabled,field=true,selected=editing})

                            bounded(vx+285,y,editing and self.text_edit.text..'|' or value,18,c.disabled and T.disabled or white,input_width-20,nil,nil,y-5,29)

                        elseif c.type=='color' then

                            rect(vx+300,y-3,34,23,api.color_rgb(value),nil,'swatch_fill');border(vx+300,y-3,34,23,T.border)
                            surface(vx+350,y-5,175,29,{enabled=not c.disabled,field=true,selected=c==selected and self.focus=='settings'})
                            bounded(vx+360,y,value,18,c.disabled and T.disabled or white,155,nil,nil,y-5,29)

                            hit(vx+295,y-7,230,34,function()if control.disabled then return end;select();self.color_picker={mod=owner,control=control,rgb=api.color_rgb((owner.handle.preview or owner.handle.get)(control.id))}end)

                        elseif c.type=='toggle' then

                            hit(vx+350,y-5,175,29,function()select();change(control,0)end)

                            surface(vx+350,y-5,175,29,{enabled=not c.disabled,field=true,selected=c==selected and self.focus=='settings'})
                            local check_x,check_y,size=vx+358,y-1.5,22
                            if c.presentation=='checkbox'then
                                rect(check_x,check_y,size,size,value and T.selected or T.panel,nil,'checkbox_box')
                                border(check_x,check_y,size,size,c.disabled and T.line or value and accent or T.muted,'widget_border')
                                if value then
                                    local unit=size/20;local ink=c.disabled and T.disabled or accent
                                    for step=0,3 do rect(check_x+(4+step)*unit,check_y+(10-step)*unit,2*unit,2*unit,ink,nil,'checkbox_mark')end
                                    for step=0,8 do rect(check_x+(7+step)*unit,check_y+(7+step)*unit,2*unit,2*unit,ink,nil,'checkbox_mark')end
                                end
                            else
                                rect(check_x,y+1,48,16,value and T.selected or T.line,nil,'switch_track')
                                border(check_x,y+1,48,16,c.disabled and T.line or value and accent or T.border_hover,'widget_border')
                                rect(check_x+(value and 27 or 3),y-1,18,20,c.disabled and T.disabled or value and accent or T.muted,nil,'switch_thumb')
                            end
                            local status=c.disabled and 'DISABLED'or(value and 'ON'or'OFF')
                            bounded(vx+(c.presentation=='checkbox'and 391 or 418),y,status,c.disabled and 14 or 19,c.disabled and T.disabled or white,c.presentation=='checkbox'and 124 or 96,nil,c.disabled and 'hint'or 'body',y-5,29)

                        elseif c.type=='choice' then

                            local presentation=Layout.choice_presentation(c.presentation)

                            local chosen=c.disabled and T.disabled or white
                            local symbol=c.disabled and T.disabled or muted
                            local cw=value_width
                            local cx=vx+525-(presentation=='selector' and 30 or 0)-cw
                            state.choice_bounds[c]={x=cx,top=y-8,width=cw}

                            if presentation=='selector' then

                                surface(cx-30,y-5,27,29,{enabled=not c.disabled});text(cx-23,text_y(y-5,29,18,'<'),'<',18,symbol)

                                surface(cx+cw+3,y-5,27,29,{enabled=not c.disabled});text(cx+cw+10,text_y(y-5,29,18,'>'),'>',18,symbol)

                                hit(cx-30,y-5,27,29,function()select();change(control,-1)end)

                                hit(cx+cw+3,y-5,27,29,function()select();change(control,1)end)

                            end

                            surface(cx,y-5,cw,29,{enabled=not c.disabled,field=true,selected=c==selected and self.focus=='settings'})

                            bounded(cx+9,y,tostring(c.choices[value]),18,chosen,cw-(presentation=='selector' and 20 or 55),nil,nil,y-5,29)

                            if presentation~='selector' then

                                -- Reserve an opaque indicator cell above the value text.

                                rect(cx+cw-32,y-3,1/s,25,T.line,nil,'control_accent');text(cx+cw-20,text_y(y-5,29,18,'v'),'v',18,symbol)

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
                            surface(bx,y-5,bw,29,{enabled=not c.disabled,field=c.type=='keybind',selected=c==selected and self.focus=='settings'})
                            bounded(bx+12,y,label,18,c.disabled and T.disabled or white,math.max(0,bw-24),nil,nil,y-5,29)

                        end

                    end

                end

            end

            text_focus=false
            scrollbar('settings',settings_x+(wide and row_width or available-10)+10,inspector and 126 or 196,wh-(inspector and 294 or 364),self.display_total,settings_visible,self.scroll)

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

            local help=selected and selected.description or page.native_binding_description or mod.description

            local key=mod.id..'/'..page.id..'/'..tostring(help)

            if state.help_key~=key then self.help_scroll=0;state.help_key=key end

            local hx=self.sidebar_width+35;local hw=ww-40-hx
            local help_bottom,help_height=126,64
            if inspector then
                hx=settings_x+row_width+Layout.column_gap;hw=ww-40-hx
                help_bottom,help_height=196,wh-380
                rect(hx-12,help_bottom,hw+24,help_height,T.panel)
                rect(hx-12,help_bottom+help_height-3,hw+24,2,accent)
                bounded(hx,help_bottom+help_height-37,'SETTING DETAILS',16,accent,hw,nil,'heading',help_bottom+help_height-43,32)
                bounded(hx,help_bottom+help_height-74,selected and selected.label or page.name,18,white,hw,nil,'body',help_bottom+help_height-82,32)
                help_height=help_height-110
                if selected and selected.default~=nil then
                    local default=selected.default
                    if selected.type=='choice'then default=selected.choices[default]
                    elseif selected.type=='toggle'then default=default and 'ON'or'OFF'
                    elseif selected.type=='keybind'then default=M.key_name(default)end
                    bounded(hx,help_bottom+54,'Default: '..tostring(default),16,muted,hw,nil,'hint',help_bottom+46,28)
                end
                if selected and selected.type=='slider'then bounded(hx,help_bottom+28,'Range: '..selected.min..' - '..selected.max..'    Step: '..selected.step,16,muted,hw,nil,'hint',help_bottom+20,28)end
                local native_editable=selected and selected.native_binding_id and type(selected.native_binding_bind)=='function' and type(selected.native_binding_available)=='function'
                local help_hint=page.native_binding_category and (native_editable and 'Click binding or press Enter to rebind' or 'Managed by Mod Bindings Menu') or 'Right click for setting options'
                bounded(hx,help_bottom+5,help_hint,14,accent,hw,nil,'hint',help_bottom,24)
                help_bottom=help_bottom+86;help_height=help_height-86
            else
                rect(hx-15,help_bottom,hw+30,help_height+4,T.panel)
            end

            local help_size=M.text_size(18,'hint',font_scale)
            local line_height=math.ceil(help_size+5)
            local lines=M.rich(help,hw*s,help_size*s,measure);local visible=math.max(1,math.floor(help_height/line_height))

            self.help_scroll=math.min(self.help_scroll,math.max(0,#lines-visible))

            state.help_bounds={x=ox+hx*s,y=oy+help_bottom*s,w=hw*s,h=help_height*s,maximum=math.max(0,#lines-visible)}

            for index=self.help_scroll+1,math.min(#lines,self.help_scroll+visible)do

                local line=lines[index];local tx=hx
                local ty=help_bottom+help_height+4-(index-self.help_scroll)*line_height+math.max(1,(line_height-line.size/s)/2)

                for _,span in ipairs(line.spans)do text(tx,ty,span.text,line.size/s,span.style=='plain' and muted or (span.style=='emphasis' and white or accent),span.style=='heading'and 'heading'or 'hint',true);tx=tx+span.width/s end

            end

            scrollbar('help',hx+hw+8,help_bottom,help_height,#lines,visible,self.help_scroll)

        end

        hit(self.sidebar_width-6,196,12,wh-310,function()state.split_drag={ox=ox,scale=s}end)

        rect(1,1,ww-2,54,T.panel)
        rect(1,55,ww-2,1,T.line)
        Branding.hazards(2,2,ww-4,3,accent,triangle)
        local shortcut=M.key_name(api.menu_toggle_key or 46)
        bounded(25,32,shortcut..' / Esc  Close     Tab  Accept / Apply     Shift+Tab  Focus     Enter  Edit',14,muted,ww-380)
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

        if #notice>0 then bounded(self.sidebar_width+35,64,notice,15,muted,ww-self.sidebar_width-60,nil,'hint',55,23)end

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
            surface_scope='dropdown'

            local d=self.dropdown;local count=math.min(8,#d.control.choices);local height=count*31+8

            local top=math.max(height+8,math.min(wh-68,d.top));local dw=math.min(ww-16,d.width or 250);local x=math.max(8,math.min(ww-dw-8,d.x))

            -- Overlay hit regions take priority and consume outside clicks.

            hit(-ox/s,-oy/s,w/s,h/s,function()self.dropdown=nil;state.scroll_drag=nil end)

            rect(x,top-height,dw,height,T.panel);border(x-2,top-height-2,dw+4,height+4,T.border,'window_frame')

            for index=d.scroll+1,math.min(#d.control.choices,d.scroll+count)do

                local y=top-29-(index-d.scroll-1)*31;local choice=index

                rect(x+3,y-4,dw-16,30,index==d.selected and T.selected or (hovering(x+3,y-4,dw-16,30)and T.hover or T.panel))
                rect(x+3,y-4,2,30,index==d.selected and accent or T.panel)

                text_focus=index==d.selected
                bounded(x+8,y,tostring(d.control.choices[index]),18,index==d.selected and white or muted,math.max(0,dw-24),nil,nil,y-4,30)

                hit(x+3,y-4,dw-16,30,function()

                    local ok,err=(d.mod.handle.edit or d.mod.handle.set)(d.control.id,choice)

                    self.notice=ok and (saved_notice(d.control,d.mod.handle)) or tostring(err);self.dropdown=nil;state.scroll_drag=nil

                end)

            end

            text_focus=false
            scrollbar('dropdown',x+dw-7,top-height+4,height-8,#d.control.choices,count,d.scroll)

            for index=overlay_start,#commands do commands[index].popup=true;commands[index].layer=200+(commands[index].surface_offset or 0) end

        end

        local pv=self.preview_window
        if pv and api.mods[pv.mod.id]~=pv.mod then self.preview_window=nil;pv=nil end
        if pv then
            surface_scope='main'
            local pw,ph=420*s,450*s
            pv.x=math.max(0,math.min(w-pw,pv.x));pv.y=math.max(0,math.min(h-ph,pv.y))
            local px,py=pv.x,pv.y
            local first=#commands+1
            local first_hit=#state.hits+1
            rect((px-ox)/s,(py-oy)/s,420,450,T.background,.98)
            border((px-ox)/s,(py-oy)/s,420,450,T.border,'window_frame')
            rect((px-ox)/s,(py-oy)/s+410,420,40,T.header)
            text((px-ox)/s+14,(py-oy)/s+423,'HUD PREVIEW',18,white,'heading')
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
            for i=first,#commands do commands[i].hud_preview=true;commands[i].layer=110+(commands[i].surface_offset or 0) end
            for i=first_hit,#state.hits do state.hits[i].context_barrier=true end
        end

        if self.color_picker then

            local p=self.color_picker;local start=#commands+1;local px,py=math.max(0,math.min(ww-704,p.x or 400)),math.max(0,math.min(wh-434,p.y or 195))
            surface_scope='picker'

            hit(-ox/s,-oy/s,w/s,h/s,function()self.color_picker=nil;self.text_edit=nil end)

            hit(px-2,py-2,704,434,function()end)

            hit(px,py+385,700,45,function(mx,my)state.color_drag={ox=ox,oy=oy,scale=s,dx=(mx-ox)/s-px,dy=(my-oy)/s-py}end)

            rect(px,py,700,430,T.panel);border(px-2,py-2,704,434,T.border,'window_frame');rect(px,py+385,700,45,T.header)

            surface(px+650,py+389,32,30);text(px+660,text_y(py+389,30,20,'X'),'X',20,white)

            hit(px+650,py+389,32,30,function()self.color_picker=nil;self.text_edit=nil end)

            text(px+20,text_y(py+385,45,22,'COLOR','heading'),'COLOR',22,white,'heading')

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

                text(px+315,text_y(fy-5,30,20,field.label),field.label,20,white)

                local editing=self.text_edit and self.text_edit.color_channel==field.key

                surface(px+370,fy-5,210,30,{field=true,selected=editing})
                bounded(px+380,fy,editing and self.text_edit.text..'|' or tostring(field.value),20,white,190,nil,nil,fy-5,30)

                hit(px+370,fy-5,210,30,function()self.text_edit={color_channel=field.key,text=tostring(field.value):gsub('^#',''),replace=true}end)

            end

            text(px+20,py+126,'CUSTOM SWATCHES',17,muted,'hint')

            for index,hex in ipairs(api.swatches())do local sx=px+20+(index-1)*38

                if p.selected_swatch==index then border(sx-3,py+76,36,36,accent)end

                rect(sx,py+79,30,30,api.color_rgb(hex))

                hit(sx,py+79,30,30,function()p.selected_swatch=index;p.rgb=api.color_rgb(hex);p.hue,p.saturation,p.brightness=api.rgb_hsv(p.rgb)end)

            end

            surface(px+500,py+78,180,32);bounded(px+510,py+88,'SAVE SWATCH',16,white,160,nil,'hint',py+78,32)

            hit(px+500,py+78,180,32,function()local ok,err=api.save_swatch(p.rgb);self.notice=ok and 'Custom swatch saved' or tostring(err)end)

            surface(px+500,py+119,180,32,{enabled=p.selected_swatch~=nil});bounded(px+510,py+129,'REPLACE',16,p.selected_swatch and white or T.disabled,160,nil,'hint',py+119,32)

            hit(px+500,py+119,180,32,function()

                if not p.selected_swatch then self.notice='Select a saved swatch first';return end

                local ok,err=api.replace_swatch(p.selected_swatch,p.rgb);self.notice=ok and 'Selected swatch replaced' or tostring(err)

            end)

            surface(px+20,py+20,300,32,{primary=true});text(px+35,text_y(py+20,32,18,'USE COLOR'),'USE COLOR',18,T.background)

            hit(px+20,py+20,300,32,function()self.commit_color()end)

            surface(px+370,py+20,310,32);text(px+390,text_y(py+20,32,18,'CANCEL'),'CANCEL',18,white)

            hit(px+370,py+20,310,32,function()self.color_picker=nil;self.text_edit=nil end)

            for index=start,#commands do commands[index].popup=true;commands[index].layer=340+(commands[index].surface_offset or 0) end

        end

        state.text_age=visible_text_age
        if self.context_menu then
            local popup=self.context_menu;surface_scope='context';shape_layer=360
            local width=220
            for _,item in ipairs(popup.items)do width=math.max(width,M.control_width(item.label,0,400*s,32*s,M.text_size(18,nil,font_scale)*s,measure)/s)end
            width=math.min(400,width);local height=46+#popup.items*34
            local px=math.max(8,math.min(ww-width-8,(popup.x-ox)/s));local py=math.max(8,math.min(wh-height-8,(popup.y-oy)/s-height))
            popup.bounds={x=ox+px*s,y=oy+py*s,w=width*s,h=height*s}
            local first=#commands+1
            hit(0,0,ww,wh,function()self.close_context()end)
            rect(px,py,width,height,T.panel);border(px,py,width,height,T.border)
            bounded(px+12,py+height-31,popup.title or 'OPTIONS',16,accent,width-24,nil,'heading',py+height-39,32)
            for index,item in ipairs(popup.items)do
                local iy=py+height-44-index*34;local enabled=item.enabled~=false
                local hover=enabled and hovering(px+4,iy,width-8,32)
                if index==popup.selected or hover then rect(px+4,iy,width-8,32,T.selected)end
                bounded(px+14,iy+8,item.label,18,enabled and white or T.disabled,width-28,nil,'body',iy,32)
                local slot=index
                hit(px+4,iy,width-8,32,function()self.run_context(slot)end)
            end
            for index=first,#commands do commands[index].popup=true;commands[index].context_action=true end
        end
        if console then for _,command in ipairs(console.compose(w,h,self.window_bounds,true))do commands[#commands+1]=command end end

        return commands

    end
end
return MODULE
