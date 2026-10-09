local api,menu,view,registered,input,log,capture;local legacy;local hud_integration,hud_runtime,native_entry;local hud_timer=0;local hud_diagnostic;local diagnostic;local binding_host;local held_toggle=false;local retired=false
local diagnostics,diagnostics_owner,log_context,original_log,mirror_log
local function close()
    -- A failed external restore must keep its provider and snapshot available.
    if capture then
        local ok,reason=(capture.shutdown or capture.release)()
        if ok==false then if log then log('MCM cursor restoration pending: '..tostring(reason))end;return false,reason end
        capture=nil
    end
    if native_entry then
        local ok,reason=native_entry.close()
        if ok==false then if log then log('MCM native cleanup pending: '..tostring(reason))end;return false,reason end
        native_entry=nil
    end
    if hud_integration then hud_integration.release();hud_integration=nil end
    if hud_runtime then hud_runtime.release();hud_runtime=nil end
    if legacy then
        -- Capture the active provider before MDL unwinds its registered globals.
        legacy.poll(rawget(_G,'ModOptionsMenu'))
        legacy.release();legacy=nil
    end
    retired=true;if registered then registered.unregister();registered=nil end
    if view then view.release();view=nil end
    if api and rawget(_G,'DBFMCM')==api then rawset(_G,'DBFMCM',nil)end
    if menu and menu.release_console then menu.release_console()end
    if diagnostics_owner then diagnostics.detach(diagnostics_owner);diagnostics_owner=nil end
    if log_context and log_context.log==mirror_log then log_context.log=original_log end
    log_context,original_log,mirror_log=nil,nil,nil
    api,menu,input=nil,nil,nil;binding_host=nil;held_toggle=false
end
return {
    name='Mod Configuration Menu (Preview)',version='0.1.56',author='HWG90',
    description='Shared mod settings. DEL opens MCM; a guarded MCM tab also opens it from the Escape menu.',
    on_enable=function(ctx)
        assert(ctx.api==2 and type(ctx.global)=='function' and type(ctx.on_cleanup)=='function','MDL API 2 required')
        assert(not rawget(_G,'DBFMCM'),'Another DBFMCM instance is active')
        local epic=package.loaded['dbf.epic_lut.frontend.v1']
        if epic and epic.active then assert(epic.suspend(),'Epic LUT cursor restoration pending; MCM activation deferred')end
        local ffi=require('ffi');local bit=require('bit')
        pcall(ffi.cdef,[[
            typedef struct {long x;long y;} DBFMCM_POINT;
            short dbfmcm_key(int) __asm__("GetAsyncKeyState");
            void *dbfmcm_foreground(void) __asm__("GetForegroundWindow");
            int dbfmcm_cursor(DBFMCM_POINT *) __asm__("GetCursorPos");
            int dbfmcm_client(void *,DBFMCM_POINT *) __asm__("ScreenToClient");
            unsigned long dbfmcm_window_process(void *,unsigned long *) __asm__("GetWindowThreadProcessId");
            unsigned long dbfmcm_process(void) __asm__("GetCurrentProcessId");
            int dbfmcm_rect(void *,long *) __asm__("GetClientRect");
            int mcm_install(void *);
            int mcm_capture(int);
            int mcm_captured(void);
            void mcm_release(void);
            int mcm_wheel(void);
        ]])
        local user=ffi.load('user32');local kernel=ffi.load('kernel32');local process=kernel.dbfmcm_process()
        local point=ffi.new('DBFMCM_POINT[1]');local rect=ffi.new('long[4]');local foreground_process=ffi.new('unsigned long[1]')
        local sr=assert(rawget(_G,'stingray'),'Stingray unavailable');retired=false
        diagnostics=MCM.console.shared()
        local loader=rawget(_G,'LiveLuaLoader')
        local path=ctx.diagnostic_log_path or (loader and loader.log_directory and loader.log_directory..'/LiveLuaLoader.log')
        diagnostics_owner=diagnostics.attach('MCM',path)
        log_context=ctx;original_log=ctx.log
        mirror_log=function(message)
            local current=rawget(_G,'LiveLuaLoader')
            if not (current and current.diagnostics==diagnostics)then pcall(diagnostics.record,'MCM',message,nil,nil,path)end
            if original_log then
                local ok,why=pcall(original_log,message)
                if not ok then pcall(diagnostics.record,'MCM','Log sink failed','error',tostring(why),path)end
            end
        end
        ctx.log=mirror_log;log=mirror_log
        ctx.on_cleanup(close)
        local native_file=assert(io.open(ctx.dir..'/library.txt','rb'),'Native capture manifest missing')
        local native_name=native_file:read('*a'):match('^(mcm_input_%x+%.dll)%s*$');native_file:close()
        assert(native_name,'Invalid native capture library name')
        local native=ffi.load(ctx.dir..'/'..native_name)
        capture=MCM.capture.new(native,assert(sr.Window,'Window API unavailable'),ctx.log)
        local folder=assert(os.getenv('LOCALAPPDATA'),'LOCALAPPDATA unavailable')..'/MDL/Helldivers2/Mods/dbf_mcm/settings'
        local storage=MCM.store.new(folder)
        if not rawget(_G,'ModOptionsMenu') then
            local compat,registry=MCM.compat.new(storage,package.loaded['dbf_mcm.compat_registry'])
            package.loaded['dbf_mcm.compat_registry']=registry -- Shared storage is not an MDL-owned global.
            ctx.global('ModOptionsMenu',compat);ctx.log('MCM provides ModOptionsMenu API 1 compatibility')
        end
        api=MCM.core.new(storage,ctx.log,MCM.grouping);MCM.authoring.install(api)
        api.diagnostics=diagnostics;api.diagnostics_surface=MCM.console.surface
        view=MCM.view.new(sr,nil,ctx.log);menu=MCM.menu.new(api,view.measure)
        input={}
        local foreground
        function input.down(code)return foreground and bit.band(tonumber(user.dbfmcm_key(code)),0x8000)~=0 or false end
        function input.mouse()
            if not foreground or user.dbfmcm_cursor(point)==0 or user.dbfmcm_client(foreground,point)==0 or user.dbfmcm_rect(foreground,rect)==0 then return end
            local w,h=sr.Gui.resolution();local cw,ch=tonumber(rect[2]),tonumber(rect[3]);if cw<=0 or ch<=0 then return end
            return tonumber(point[0].x)*w/cw,h-tonumber(point[0].y)*h/ch
        end
        function input.poll()
            foreground=user.dbfmcm_foreground();user.dbfmcm_window_process(foreground,foreground_process)
            if foreground_process[0]~=process then foreground=nil end
        end
        function input.wheel()return tonumber(native.mcm_wheel())end
        function input.focused()return foreground~=nil end
        function input.window()return foreground end
        api.input_lease={acquire=function(owner)return capture.acquire(owner)end,owns=function(token)return capture.owns(token)end,release=function(token)
            if token==nil then return false,'Lease token required'end
            return capture.release(token)
        end}
        function api.input_status()return capture and capture.status() or {active=false}end
        function api.open()menu.visible=true;return true end
        function api.close()
            menu.visible=false;menu.capture=false
            if menu.release_console then menu.release_console()end
            local ok,reason=true,nil
            if capture then ok,reason=capture.release()end
            if ok~=false then menu.native_parent=nil end
            if view then view.release()end
            return ok,reason
        end
        function api.is_open()return menu.visible end
        function api.menu_binding_status()return {focused=input.focused(),editing=menu.capture~=false or menu.text_edit~=nil or menu.color_picker~=nil,global_key=api.menu_toggle_key or 46}end
        function api.focus_page(mod_id,page_id)
            if not input.focused()then return false,'Game is not focused'end
            for index,mod in ipairs(api.list())do if mod.id==mod_id then
                for page_index,page in ipairs(mod.pages)do if page.id==page_id then menu.selected=index;menu.page=page_index;menu.row=1;menu.scroll=0;menu.focus='settings';menu.visible=true;return true end end
            end end
            return false,'Requested page unavailable'
        end
        ctx.global('DBFMCM',api)
        legacy=MCM.legacy.new(api,ctx.log,MCM.core)
        local definition=MCM.framework({example_action=function()ctx.log('MCM example action activated')end},MCM.authoring)
        local actions={}
        actions.reset_window=function()
            local ok,reason=MCM.preferences.reset_window(menu,registered);assert(ok,reason);return reason
        end
        local launch=MCM.platform.windows_launcher(ffi)
        actions.open_github=function()
            local ok,reason=MCM.platform.open_github(api.close,launch);assert(ok,reason);return reason
        end
        table.insert(definition.pages,1,MCM.preferences.page(function(key)
            local ok,reason=MCM.preferences.apply(api,menu,registered,key)
            if not ok then ctx.log('MCM preference update failed: '..tostring(reason));menu.notice=tostring(reason)end
        end,actions))
        registered=api.register(definition)
        api.settings_mod_id=registered.id;api.settings_page_id='mcm_settings'
        local ok,reason=MCM.preferences.apply(api,menu,registered)
        if reason then ctx.log('MCM preferences: '..tostring(reason));menu.notice=tostring(reason)end
        if not ok then api.menu_toggle_key=46 end
        ctx.log('MCM preview enabled; menu shortcut '..MCM.menu.key_name(api.menu_toggle_key or 46)..'.')
        hud_runtime=MCM.hud_plus_runtime.new(ctx.dir,ctx.log)
        hud_integration=MCM.hud_plus.new(api,ctx.log);hud_timer=0
        local recovered=hud_runtime.poll()
        if not recovered then
            local resource='mods/hd2_hud/hd2_hud_plus'
            local checked,available=pcall(sr.Application.can_get,'lua',resource)
            local cached=package.loaded[resource]
            ctx.log('HUD+ startup: resource='..tostring(checked and available)..' cached='..type(cached)..' installed='..tostring(type(cached)=='table'and rawget(cached,'installed')or false))
            if checked and available==true and cached==nil then
                local started,result=pcall(require,resource)
                ctx.log('HUD+ startup: loaded='..tostring(started)..' installed='..tostring(type(result)=='table'and result.installed or false))
                if not started then ctx.log('HUD+ startup failure: '..tostring(result))end
                hud_runtime.poll()
            end
        end
        hud_integration.poll(hud_runtime.poll())
        hud_diagnostic=hud_runtime.diagnostic()..'; '..hud_integration.diagnostic();ctx.log('HUD+ integration: '..hud_diagnostic)
        local function native_open_ready()
            input.poll()
            if not input.focused()or menu.visible or capture.status().owner then return false,'MCM input is already owned'end
            if tonumber(native.mcm_captured())~=0 then return false,'Native input belongs to another frontend'end
            if input.down(1)or input.down(2)then return false,'Waiting for the native menu click to release'end
            return true
        end
        native_entry=MCM.native_entry.new(api,{window=sr.Window,log=ctx.log,dismiss_escape=true,
            dependencies={memory=MCM.native_memory,runtime=MCM.native_runtime},
            focused=function()input.poll();return input.focused()end,
            can_open=native_open_ready,
            hud_menu=function()
                local bridge=hud_runtime and hud_runtime.poll()
                if type(bridge)=='table'and bridge.api==1 and bridge.version=='0.2.2'and
                    type(bridge.alive)=='function'and type(bridge.native_menu)=='function'and bridge.alive()==true then
                    return bridge.native_menu(),true
                end
                return nil,false
            end,
            on_open=function(parent)
                local ready,why=native_open_ready();if not ready then return false,why end
                if parent.validate()~=true then return false,'Native MCM parent could not be verified'end
                local saved=parent.restoration_snapshot
                if type(saved.focus)~='boolean'or type(saved.cursor)~='boolean'or type(saved.clip)~='boolean'then return false,'Native MCM cursor snapshot is invalid'end
                menu.native_parent=parent;menu.visible=true;return true
            end,
            on_detached=function(proof)
                local ready,why=native_open_ready();if not ready then return false,why end
                if type(proof)~='table'or type(proof.validate)~='function'or proof.validate()~=true then return false,'Escape close was not verified'end
                if sr.Window.mouse_focus()~=true then return false,'Waiting for game input after Escape close'end
                menu.native_parent=nil;menu.visible=true;return true
            end})
        -- Adapter cleanup restores capture first, then native selection and hook ownership.
        local native_ok,native_why=native_entry.install()
        if not native_ok then ctx.log('MCM native entry unavailable: '..tostring(native_why))else ctx.log('MCM native entry: verified update hook installed')end
        function api.integration_status()return {hud=hud_runtime and hud_runtime.diagnostic(),native=native_entry and native_entry.status()}end


    end,
    on_update=function(ctx,dt)
        if retired or not api then return end
        local ok,err=pcall(function()
            input.poll()
            -- Loaders can cache their update entry; lifecycle polling still
            -- runs even when a newly installed global wrapper is not called.
            if native_entry then native_entry.step()end
            hud_timer=hud_timer+math.max(0,tonumber(dt)or 0)
            if hud_timer>=.25 then
                hud_timer=0
                local bridge=hud_runtime and hud_runtime.poll()
                if hud_integration then hud_integration.poll(bridge)end
                if hud_runtime and hud_integration then local report=hud_runtime.diagnostic()..'; '..hud_integration.diagnostic();if report~=hud_diagnostic then hud_diagnostic=report;ctx.log('HUD+ integration: '..report)end end
            end
            legacy.poll(rawget(_G,'ModOptionsMenu'))
            api.mount('dbf_ass_blacklist',"Diver's Best Friend")
            local report=legacy.diagnostic()
            if report~=diagnostic then
                diagnostic=report;ctx.log('Legacy registry: '..report)
                local f=io.open(os.getenv('LOCALAPPDATA')..'/MDL/Helldivers2/Logs/MCM-diagnostic.log','w')
                if f then f:write(report,'\n');f:close()end
            end
            -- Native binding action aliases can collide with game menu navigation.
            -- Use the saved physical key edge; native action aliases may collide.
            local focused=input.focused()
            local process_input=menu.input_focus(focused,input)
            if process_input and not menu.visible then menu.tick(input);process_input=false end
            if retired or not menu then return end
            -- Release the manager before snapshotting game cursor flags.
            local loader=rawget(_G,'LiveLuaLoader')
            if focused and menu.visible and not capture.active and loader and type(loader.close_manager)=='function' then
                local released,why=loader.close_manager()
                if released==false then menu.visible=false;ctx.log('MCM handoff refused: '..tostring(why))end
            elseif focused and menu.visible and not capture.active and loader and type(loader.open_manager)=='function' then
                menu.visible=false;ctx.log('MCM handoff refused: loader lacks safe close_manager API')
            end
            local acquired,reason=capture.sync(menu.visible,focused,input.window(),menu.native_parent)
            if not acquired and (tostring(reason):find('Cannot acquire input capture',1,true)or tostring(reason):find('Input capture lost',1,true)or tostring(reason):find('Window capture unavailable',1,true))then view.release();return end
            if not acquired then menu.visible=false;menu.capture=false;capture.release();ctx.log('Menu closed: '..tostring(reason))end
            if acquired and process_input then menu.tick(input)end
            if retired or not menu then return end
            if not menu.visible and capture.active then capture.release()end
            if not menu.visible and not capture.status().pending_restore then menu.native_parent=nil end
            menu.advance(dt)
            local w,h=stingray.Gui.resolution();view.draw(menu.compose(w,h))
        end)
        if not ok and not retired and menu then
            ctx.log('MCM frame failed; menu closed safely: '..tostring(err))
            menu.recover()
            if capture then pcall(capture.release)end;if view then pcall(view.release)end
            -- Keep registrations and the menu shortcut listener alive for recovery.
        end
    end,
    on_disable=close,
    on_cleanup_poll=close,
}
