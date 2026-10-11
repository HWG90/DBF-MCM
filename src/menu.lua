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
local Layout=dependencies and dependencies.layout or source_module('layout')
local Branding=dependencies and dependencies.branding or source_module('branding')
local M={palette=Theme.workspace,legacy_palette=Theme.palette,text_size=Theme.text_size,
    key_name=Theme.key_name,flow=Text.flow,rich=Text.rich,control_width=Text.control_width,layout=Layout,branding=Branding}
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
    local console=api.diagnostics and api.diagnostics_surface and api.diagnostics_surface(api.diagnostics,{palette=M.palette,explicit_open=true})
    function self.release_console()if console then console.release()end end
    function self.set_command_bus(bus)
        if not api.diagnostics then return false,'Diagnostics service unavailable'end
        if bus and (type(bus)~='table'or type(bus.suggest)~='function'or type(bus.execute)~='function')then return false,'Typed command service required'end
        api.diagnostics.commands=bus;return true
    end
    function self.open_console()
        if not console or not console.focus then return false,'Typed console unavailable'end
        self.context_menu=nil;console.focus();return true
    end

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
                self.dropdown=nil;self.context_menu=nil;state.scroll_drag=nil;state.manual_scroll=true;state.tree_manual=false
                if returning then self.settings_return=nil end
                return true
            end end
        end end
        return false,'MCM settings are unavailable'
    end

    function self.recover()
        self.release_console()

        self.visible=false;self.capture=false;self.text_edit=nil;self.color_picker=nil;self.dropdown=nil;self.context_menu=nil;state.scroll_drag=nil;self.mouse_held=false;self.right_held=false

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

    function self.apply_page(mod,page)
        mod,page=mod or select(1,active()),page or select(2,active())
        if not mod or not page then return false,'No settings page is selected'end
        local called,ok,why=pcall(mod.handle.confirm,page.id)
        self.notice=called and ok and ('Confirmed and saved'..(why and '; '..tostring(why)or ''))or tostring(called and why or ok)
        return called and ok,self.notice
    end
    function self.discard_page(mod,page)
        mod,page=mod or select(1,active()),page or select(2,active())
        if not mod or not page then return false,'No settings page is selected'end
        local called,ok,why=pcall(mod.handle.discard,page.id)
        self.notice=called and ok~=false and 'Pending edits discarded'or tostring(called and why or ok)
        return called and ok~=false,self.notice
    end
    local function authoritative(control)
        local seen={}
        while control and control.source_mod_id and not seen[control]do
            seen[control]=true;local owner=api.mods[control.source_mod_id]
            control=owner and owner.controls[control.source_control_id]
        end
        return control
    end
    function self.select_target(target)
        local wanted=target.mod and target.mod.id
        for index,mod in ipairs(api.list())do if mod.id==wanted then
            local page_index=1
            if target.page then for position,page in ipairs(mod.pages)do if page.id==target.page.id then page_index=position;break end end end
            if self.selected~=index or self.page~=page_index then self.scroll=0 end
            self.selected,self.page=index,page_index;self.focus='settings';state.current=mod
            self.row=target.row or 1
            if target.control and not target.row then for position,control in ipairs(selectable(mod.pages[page_index]))do if control.id==target.control.id then self.row=position;break end end end
            state.manual_scroll=false;state.tree_manual=true;return true
        end end
        return false,'Mod is no longer registered'
    end
    function self.close_context()self.context_menu=nil end
    function self.run_context(index)
        local popup=self.context_menu;local item=popup and popup.items[index or popup.selected]
        if not item or item.enabled==false then return false,'Context action unavailable'end
        if popup.owner_id and not api.mods[popup.owner_id]then self.context_menu=nil;self.notice='Mod is no longer registered';return false,self.notice end
        self.context_menu=nil
        local called,ok,why=pcall(item.action)
        if not called or ok==false then self.notice=tostring(called and why or ok);return false,self.notice end
        return true,why
    end
    -- x/y are screen pixels. Rendering owns fitting/clamping and registers
    -- item hits with run_context(index); opening never writes a setting.
    function self.open_context(target,x,y)
        if not self.visible or self.capture or self.text_edit or self.color_picker or self.dropdown then return false,'Finish the active editor first'end
        target=target or {kind='navigation'}
        local items={};local mod=target.mod;local page=target.page;local control=target.control
        local function add(label,enabled,action)items[#items+1]={label=label,enabled=enabled==true,action=action}end
        local pending=page and (next(page.pending or {})or next(page.actions or {}))~=nil
        if target.kind=='control'and mod and control then
            local original=authoritative(control)
            local editable=original and not original.disabled and not control.disabled
            if control.collapsible then add(section_open(page or control.page,control)and 'Collapse section'or 'Expand section',true,function()
                local ok,why=self.select_target(target);if not ok then return false,why end
                change(control,0);return true
            end)
            elseif control.type~='text'and control.type~='section'then add(control.type=='button'and 'Run action'or control.type=='toggle'and 'Toggle setting'or 'Edit value',editable,function()
                local current=authoritative(control)
                if not current or current.disabled or control.disabled then return false,'Setting unavailable'end
                local ok,why=self.select_target(target);if not ok then return false,why end
                change(control,0);return true
            end)end
            if original and original.default~=nil then add('Reset to default',editable,function()
                local current=authoritative(control)
                if not current or current.disabled or control.disabled then return false,'Setting unavailable'end
                local called,ok,why=pcall(mod.handle.edit or mod.handle.set,control.id,current.default)
                self.notice=called and ok and ('Default restored; '..saved_notice(control,mod.handle))or tostring(called and why or ok)
                return called and ok,self.notice
            end)end
            local clipboard=api.clipboard;local write=clipboard and (clipboard.write or clipboard.set)
            if control.id and type(write)=='function'then add('Copy setting ID',true,function()return write(control.source_control_id or control.id)end)end
        elseif target.kind=='category'and target.key then
            local open=state.expanded[target.key];if open==nil then open=not(target.category and target.category.collapsed)end
            add(open and 'Collapse category'or 'Expand category',true,function()state.expanded[target.key]=not open;state.tree_manual=true;return true end)
        elseif mod then
            add(target.kind=='page'and 'Open page'or 'Open mod settings',true,function()return self.select_target(target)end)
            if target.kind=='mod'then
                local open=state.tree_expanded[mod.id]==true
                add(open and 'Collapse mod'or 'Expand mod',true,function()state.tree_expanded[mod.id]=not open;state.tree_manual=true;return true end)
            end
            if page then
                for _,open in ipairs({true,false})do local expand=open
                    add(expand and 'Expand sections'or 'Collapse sections',true,function()
                        for _,entry in ipairs(page.controls)do if entry.collapsible then state.section_state[mod.id..'/'..page.id..'/'..entry.id]=expand end end
                        state.manual_scroll=false;return true
                    end)
                end
            end
        else
            add('Expand all mods',true,function()for _,entry in ipairs(api.list())do state.tree_expanded[entry.id]=true end;state.tree_manual=true;return true end)
            add('Collapse all mods',true,function()state.tree_expanded={};state.tree_manual=true;return true end)
            add('MCM settings',api.settings_mod_id~=nil,function()return self.open_settings()end)
            add('Open console',console and console.focus~=nil,function()return self.open_console()end)
        end
        if mod and page then
            add('Apply page changes',pending,function()return self.apply_page(mod,page)end)
            add('Discard page changes',pending,function()return self.discard_page(mod,page)end)
        end
        if mod and type(api.open_mod_log)=='function'then add('Open mod log',true,function()return api.open_mod_log(mod.id)end)end
        local selected=1;for index,item in ipairs(items)do if item.enabled then selected=index;break end end
        self.context_menu={x=x or self.pointer_x or 0,y=y or self.pointer_y or 0,items=items,selected=selected,
            title=control and control.label or page and page.name or mod and mod.name or 'Navigation',owner_id=mod and mod.id}
        state.scroll_drag=nil;state.drag=nil;return true
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

    function self.advance(dt)
        state.dt=math.max(0,math.min(1,tonumber(dt)or 0))
        if self.visible then state.elapsed=state.elapsed+state.dt else state.elapsed=0;state.text_age={}end
    end

    local context={self=self,api=api,measure=measure,console=console,state=state,M=M,helpers={
        active=active,state_key=state_key,section_open=section_open,visible_controls=visible_controls,
        selectable=selectable,change=change,saved_notice=saved_notice,deferred=deferred}}
    Input.install(context);Render.install(context)
    return self

end

return M
