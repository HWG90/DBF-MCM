-- Menu controller: registration navigation, drafts and editor actions.
local dependencies=...
local function source_module(name)
    local source=debug.getinfo(1,'S').source:sub(2):gsub('\\','/')
    local folder=source:match('^(.*)/[^/]+$')or 'src'
    return assert(loadfile(folder..'/ui/'..name..'.lua'))()
end
local Theme=dependencies and dependencies.theme or source_module('theme')
local Text=dependencies and dependencies.text or source_module('text')
local Input=dependencies and dependencies.input or source_module('input')
local Render=dependencies and dependencies.render or source_module('render')
local M={palette=Theme.palette,key_name=Theme.key_name,flow=Text.flow,rich=Text.rich,control_width=Text.control_width}
local function deferred(c)return c and c.page and c.page.require_confirmation and c.require_confirmation~=false end
local function saved_notice(c,handle)
    if handle and c.id and handle.preview and handle.get then
        local ok,preview=pcall(handle.preview,c.id);local got,value=pcall(handle.get,c.id)
        if ok and got then return preview~=value and 'Changes ready to apply' or 'Saved'end
    end
    return deferred(c)and 'Changes ready to apply' or 'Saved'
end
function M.new(api,measure)

    local self={visible=false,focus='mods',selected=1,page=1,row=1,mod_scroll=0,scroll=0,notice='',capture=false}
    local state={tree_expanded={},tree_scroll=0,tree_manual=false,tree_max=0,expanded={},nav_scroll=0,
        wheel_remainder=0,manual_scroll=false,choice_bounds={},hits={},held={},section_state={},text_age={},elapsed=0}
    local console=api.diagnostics and api.diagnostics_surface and api.diagnostics_surface(api.diagnostics)
    function self.release_console()if console then console.release()end end

    self.sidebar_width=330;self.help_scroll=0

    function self.open_settings()
        if self.capture or self.text_edit or self.color_picker then return false,'Finish the active editor first'end
        local mods=api.list();local mod=mods[self.selected];local page=mod and mod.pages[self.page]
        local target_mod,target_page=api.settings_mod_id,api.settings_page_id or 'mcm_settings'
        local returning=mod and mod.id==target_mod and page and page.id==target_page and self.settings_return
        local target=returning and self.settings_return or {mod_id=target_mod,page_id=target_page,row=1,scroll=0,focus='settings'}
        for index,item in ipairs(mods)do if item.id==target.mod_id then
            for page_index,entry in ipairs(item.pages)do if entry.id==target.page_id then
                if not returning and mod and page then self.settings_return={mod_id=mod.id,page_id=page.id,row=self.row,scroll=self.scroll,focus=self.focus}end
                self.selected,self.page,self.row,self.scroll,self.focus=index,page_index,target.row,target.scroll,target.focus
                self.dropdown=nil;state.scroll_drag=nil;state.manual_scroll=true;state.tree_manual=false
                if returning then self.settings_return=nil end
                return true
            end end
        end end
        return false,'MCM settings are unavailable'
    end

    function self.recover()
        self.release_console()

        self.visible=false;self.capture=false;self.text_edit=nil;self.color_picker=nil;self.dropdown=nil;state.scroll_drag=nil;self.mouse_held=false

        state.drag=nil;state.window_drag=nil;state.window_resize=nil;state.color_drag=nil;state.palette_drag=nil;state.split_drag=nil;state.preview_drag=nil;state.scroll_drag=nil;self.preview_window=nil
        self.pointer_x,self.pointer_y=nil,nil

        self.notice='Menu closed after an error; use the menu shortcut to reopen it'

    end

    local function active()

        local mods=api.list();self.selected=math.max(1,math.min(self.selected,#mods));state.current=mods[self.selected]

        if state.current then self.page=math.max(1,math.min(self.page,#state.current.pages));return state.current,state.current.pages[self.page]end

    end

    local function state_key(page,id)return tostring(state.current and state.current.id)..'/'..page.id..'/'..id end
    local function section_open(page,c)
        local value=state.section_state[state_key(page,c.id)]
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

        if not state.current or c.disabled then return end

        if c.collapsible then
            local key=state_key(c.page,c.id);local open=section_open(c.page,c)
            state.section_state[key]=direction==0 and not open or direction>0
            state.manual_scroll=false;return
        end
        local h=state.current.handle;local ok,err=true

        if c.type=='button' then if direction==0 then ok,err=(h.queue or h.activate)(c.id)end

        elseif c.type=='input' then self.text_edit={mod=state.current,control=c,text=(h.preview or h.get)(c.id),replace=true};self.notice='Type name; Enter accepts';return

        elseif c.type=='keybind' then self.capture=c;self.notice='Press a key. Escape cancels.';return

        elseif c.type=='color' then

            self.color_picker={mod=state.current,control=c,rgb=api.color_rgb((h.preview or h.get)(c.id))};return

        elseif c.type=='choice' and direction==0 and c.presentation~='selector' then
            local value=(h.preview or h.get)(c.id);local anchor=state.choice_bounds[c] or {x=self.sidebar_width+50,top=(self.window_height or self.default_window_height or 820)-205,width=280}
            self.dropdown={mod=state.current,control=c,selected=value,scroll=math.max(0,math.min(math.max(0,#c.choices-8),value-4)),x=anchor.x,top=anchor.top,width=anchor.width}
            return

        else

            local v=(h.preview or h.get)(c.id)

            if c.type=='toggle' then v=not v

            elseif c.type=='choice' then v=(v-1+(direction==0 and 1 or direction))%#c.choices+1

            elseif c.type=='slider' then v=math.max(c.min,math.min(c.max,v+(direction==0 and 1 or direction)*c.step))

            else return end

            ok,err=(h.edit or h.set)(c.id,v)

        end

        self.notice=ok and (c.type=='button' and (c.require_confirmation and 'Action ready to apply' or (type(err)=='string' and err or 'Action completed')) or saved_notice(c,h)) or ('Could not save: '..tostring(err))

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

        if called and ok then self.notice=saved_notice(p.control,p.mod.handle);self.color_picker=nil

        else self.notice=tostring(called and err or ok)end

    end

    function self.sidebar()

        local rows={}

        for index,mod in ipairs(api.list())do

            local open=state.tree_expanded[mod.id]==true

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

                local key=mod.id..'/'..category.id;local open=state.expanded[key];if open==nil then open=not category.collapsed end

                local leaf,leaf_index,count=nil,nil,0
                if category.style=='page' then
                    for index,page in ipairs(mod.pages)do if page.category==category.id then leaf=page;leaf_index=index;count=count+1 end end
                    for _,child in ipairs(mod.categories or {})do if child.parent==category.id then count=count+2 end end
                end
                if count==1 then
                    rows[#rows+1]={kind='page',page=leaf,index=leaf_index,depth=depth}
                else
                rows[#rows+1]={kind='category',category=category,key=key,open=open,depth=depth}

                if open then children(category.id,depth+1)end
                end

            end end

            for index,page in ipairs(mod.pages)do if page.category==parent then rows[#rows+1]={kind='page',page=page,index=index,depth=depth}end end

        end

        children(nil,0);return rows

    end

    function self.advance(dt)if self.visible then state.elapsed=state.elapsed+math.max(0,math.min(1,tonumber(dt) or 0))else state.elapsed=0;state.text_age={}end end

    local context={self=self,api=api,measure=measure,console=console,state=state,M=M,helpers={
        active=active,state_key=state_key,section_open=section_open,visible_controls=visible_controls,
        selectable=selectable,change=change,saved_notice=saved_notice,deferred=deferred}}
    Input.install(context);Render.install(context)
    return self

end

return M
