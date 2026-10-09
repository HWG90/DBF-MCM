-- Keyboard, pointer and drag ownership; no native hooks.
local MODULE={}
function MODULE.install(context)
    local self,api,console,state=context.self,context.api,context.console,context.state
    local active,selectable,change,saved_notice=context.helpers.active,context.helpers.selectable,context.helpers.change,context.helpers.saved_notice
    function self.key(code,ctrl)

        local toggle=code==(api.menu_toggle_key or 46) and not self.capture and not self.text_edit and not self.color_picker
        if toggle then state.drag=nil;state.window_drag=nil;state.window_resize=nil;self.dropdown=nil;state.scroll_drag=nil end

        if toggle then self.visible=not self.visible;self.capture=false;return end

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

                self.notice=saved_notice(e.control,e.mod.handle);self.text_edit=nil;return

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

            if code==27 then self.dropdown=nil;state.scroll_drag=nil;return end

            if code==38 or code==40 or code==33 or code==34 then

                local step=code==33 and -8 or (code==34 and 8 or (code==38 and -1 or 1))

                d.selected=math.max(1,math.min(#d.control.choices,d.selected+step))

                if d.selected<=d.scroll then d.scroll=d.selected-1 end

                if d.selected>d.scroll+8 then d.scroll=d.selected-8 end

                return

            end

            if code==13 then

                local ok,err=(d.mod.handle.edit or d.mod.handle.set)(d.control.id,d.selected)

                self.notice=ok and (saved_notice(d.control,d.mod.handle)) or tostring(err)

                self.dropdown=nil;state.scroll_drag=nil;return

            end

            return

        end

        state.manual_scroll=false;state.tree_manual=false

        local mod,page=active();if not mod then if code==27 then self.visible=false end;return end

        if self.capture then

            local c=self.capture;self.capture=false

            if code~=27 then
                local called,ok,err=pcall(mod.handle.edit or mod.handle.set,c.id,code)
                self.notice=called and ok and saved_notice(c,mod.handle)or tostring(called and err or ok)
            end

            return

        end

        if code==27 then
            if self.preview_window then self.preview_window=nil;state.preview_drag=nil;return end
            self.visible=false;state.scroll_drag=nil;return end

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

            elseif c and (code==37 or code==39 or code==13) then change(c,code==13 and 0 or (code==37 and -1 or 1))end

        end

    end

    function self.wheel(delta,x,y)

        if not self.visible or self.capture or not state.wheel_bounds or not x or not y then return end

        if self.dropdown then

            local d=self.dropdown;d.scroll=math.max(0,math.min(math.max(0,#d.control.choices-8),d.scroll-delta/120*3));d.scroll=math.floor(d.scroll);return

        end

        if state.help_bounds and x>=state.help_bounds.x and x<=state.help_bounds.x+state.help_bounds.w and y>=state.help_bounds.y and y<=state.help_bounds.y+state.help_bounds.h then self.help_scroll=math.max(0,math.min(state.help_bounds.maximum,self.help_scroll-math.floor(delta/120)*3));return end

        if state.nav_bounds and x>=state.nav_bounds.x and x<=state.nav_bounds.x+state.nav_bounds.w and y>=state.nav_bounds.y and y<=state.nav_bounds.y+state.nav_bounds.h then

            state.nav_scroll=math.max(0,math.min(state.nav_bounds.maximum,state.nav_scroll-math.floor(delta/120)*3));return

        end

        local b=state.wheel_bounds;if x<b.x or x>b.x+b.w or y<b.y or y>b.y+b.h then return end

        state.wheel_remainder=state.wheel_remainder+delta

        local steps=state.wheel_remainder>=0 and math.floor(state.wheel_remainder/120) or math.ceil(state.wheel_remainder/120)

        state.wheel_remainder=state.wheel_remainder-steps*120;if steps==0 then return end

        local mod,page=active();if not mod then return end

        if x<b.split then

            state.tree_scroll=math.max(0,math.min(state.tree_max,state.tree_scroll-steps*3));state.tree_manual=true

        else

            self.scroll=math.max(0,math.min(math.max(0,(self.display_total or #page.controls)-(self.settings_visible or 12)),self.scroll-steps*3));state.manual_scroll=true

        end

    end

    function self.input_focus(focused,input)
        if not focused then
            if console then console.release()end
            state.drag=nil;state.window_drag=nil;state.window_resize=nil;state.scroll_drag=nil;self.capture=false;self.mouse_held=false;self.suspended=true;self.pointer_x,self.pointer_y=nil,nil
            return false
        end
        if self.suspended then
            for code=1,255 do state.held[code]=input.down(code)end
            self.mouse_held=input.down(1);self.suspended=false
            return false -- Do not replay keys/clicks held in another application.
        end
        return true
    end
    function self.tick(input)
        if console then input=console.filter(input,self.visible)end

        if not self.visible then

            local key=api.menu_toggle_key or 46
            local down=input.down(key);if down and not state.held[key] then self.key(key)end;state.held[key]=down

            return

        end

        if not self.color_picker and not state.drag and not state.window_drag and not state.window_resize and not self.text_edit and input.wheel and input.mouse then local delta=input.wheel();local x,y=input.mouse();self.wheel(delta,x,y)end

        for code=1,255 do local down=input.down(code);if down and not state.held[code] and code~=1 then self.key(code,input.down(17))end;state.held[code]=down end

        if self.visible and input.mouse then

            local x,y=input.mouse();self.pointer_x,self.pointer_y=x,y;if x and y and input.down(1) and not self.mouse_held then

                local valid=self.finish_color_field()

                if self.text_edit and self.text_edit.control and self.text_edit.control.type=='input' then

                    self.key(13)

                    valid=self.text_edit==nil

                end

                if valid then self.text_edit=nil end

                for i=#state.hits,1,-1 do local h=state.hits[i];if x>=h.x and x<=h.x+h.w and y>=h.y and y<=h.y+h.h then if valid then h.click(x,y)end;break end end

            end

            if state.scroll_drag then
                if not self.visible or not input.down(1)then state.scroll_drag=nil
                elseif y then state.scroll_drag.move(y)end
            end

            if state.palette_drag then

                if not self.color_picker or not input.down(1)then state.palette_drag=nil

                elseif x and y then state.palette_drag(x,y)end

            end

            if state.color_drag then

                if not self.color_picker or not input.down(1)then state.color_drag=nil

                elseif x and y then

                    self.color_picker.x=math.max(0,math.min(math.max(0,(self.window_width or self.default_window_width or 1500)-704),(x-state.color_drag.ox)/state.color_drag.scale-state.color_drag.dx))

                    self.color_picker.y=math.max(0,math.min(math.max(0,(self.window_height or self.default_window_height or 820)-434),(y-state.color_drag.oy)/state.color_drag.scale-state.color_drag.dy))

                end

            end

            if state.split_drag then

                if not self.visible or not input.down(1)then state.split_drag=nil elseif x then self.sidebar_width=math.max(250,math.min(math.min(650,(self.window_width or self.default_window_width or 1500)-700),(x-state.split_drag.ox)/state.split_drag.scale))end

            end

            if state.preview_drag then
                if not self.visible or not self.preview_window or not input.down(1) then state.preview_drag=nil
                elseif x and y then
                    self.preview_window.x=math.max(0,math.min(state.preview_drag.max_x,x-state.preview_drag.dx))
                    self.preview_window.y=math.max(0,math.min(state.preview_drag.max_y,y-state.preview_drag.dy))
                end
            end
            if state.window_resize then
                if not self.visible or not input.down(1)then state.window_resize=nil
                elseif x and y then
                    local r=state.window_resize;local left,right,bottom,top=r.left,r.right,r.bottom,r.top
                    if r.edge:find('w',1,true)then left=math.max(0,math.min(right-r.min_w,x))end
                    if r.edge:find('e',1,true)then right=math.min(r.screen_w,math.max(left+r.min_w,x))end
                    if r.edge:find('s',1,true)then bottom=math.max(0,math.min(top-r.min_h,y))end
                    if r.edge:find('n',1,true)then top=math.min(r.screen_h,math.max(bottom+r.min_h,y))end
                    self.window_x,self.window_y=left,bottom
                    self.window_width,self.window_height=(right-left)/r.scale,(top-bottom)/r.scale
                    self.dropdown=nil;state.scroll_drag=nil
                end
            end
            if state.window_drag then

                if not self.visible or not input.down(1)then state.window_drag=nil

                elseif x and y then

                    self.window_x=math.max(0,math.min(state.window_drag.max_x,x-state.window_drag.dx))

                    self.window_y=math.max(0,math.min(state.window_drag.max_y,y-state.window_drag.dy))

                end

            end

            if state.drag then

                if not self.visible then state.drag=nil

                elseif input.down(1) then if x then state.drag.move(x)end

                else

                    local ok,err=(state.drag.mod.handle.edit or state.drag.mod.handle.set)(state.drag.control.id,state.drag.value)

                    self.notice=ok and (saved_notice(state.drag.control,state.drag.mod.handle)) or ('Could not save: '..tostring(err));state.drag=nil

                end

            end

            self.mouse_held=input.down(1)

        else self.mouse_held=input.down(1)end

    end

end
return MODULE
