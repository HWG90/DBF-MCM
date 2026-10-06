local api,menu,view,registered,input,log,capture;local legacy;local diagnostic;local binding_host;local held_toggle=false;local retired=false
local diagnostics,diagnostics_owner,log_context,original_log,mirror_log
local function close()
    -- A failed external restore must keep its provider and snapshot available.
    if capture then
        local ok,reason=(capture.shutdown or capture.release)()
        if ok==false then if log then log('MCM cursor restoration pending: '..tostring(reason))end;return false,reason end
        capture=nil
    end
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
    name='Mod Configuration Menu (Preview)',version='0.1.51',author='HWG90',
    description='Independent MCM-style author framework. F10 opens a keyboard/mouse preview. Not yet a native pause-menu replacement.',
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
        function api.open()menu.visible=true end
        function api.close()
            menu.visible=false;menu.capture=false
            if menu.release_console then menu.release_console()end
            local ok,reason=true,nil
            if capture then ok,reason=capture.release()end
            if view then view.release()end
            return ok,reason
        end
        function api.is_open()return menu.visible end
        function api.menu_binding_status()return {focused=input.focused(),editing=menu.capture~=false or menu.text_edit~=nil or menu.color_picker~=nil,global_key=121}end
        function api.focus_page(mod_id,page_id)
            if not input.focused()then return false,'Game is not focused'end
            for index,mod in ipairs(api.list())do if mod.id==mod_id then
                for page_index,page in ipairs(mod.pages)do if page.id==page_id then menu.selected=index;menu.page=page_index;menu.row=1;menu.scroll=0;menu.focus='settings';menu.visible=true;return true end end
            end end
            return false,'Requested page unavailable'
        end
        ctx.global('DBFMCM',api)
        legacy=MCM.legacy.new(api,ctx.log,MCM.core)
        registered=api.register(MCM.framework({example_action=function()ctx.log('MCM example action activated')end},MCM.authoring))
        ctx.log('IMMEDIATE_CAPTURE_RELEASE_0148 20261004; MCM preview enabled; F10 opens the menu. Existing Mod Options Menu is unchanged.')
    end,
    on_update=function(ctx,dt)
        if retired or not api then return end
        local ok,err=pcall(function()
            input.poll()
            legacy.poll(rawget(_G,'ModOptionsMenu'))
            api.mount('dbf_ass_blacklist',"Diver's Best Friend")
            local report=legacy.diagnostic()
            if report~=diagnostic then
                diagnostic=report;ctx.log('Legacy registry: '..report)
                local f=io.open(os.getenv('LOCALAPPDATA')..'/MDL/Helldivers2/Logs/MCM-diagnostic.log','w')
                if f then f:write(report,'\n');f:close()end
            end
            -- Native binding action aliases can collide with game menu navigation.
            -- Use the physical F10 edge until an independent action is verified.
            local focused=input.focused()
            if menu.input_focus(focused,input)then menu.tick(input)end
            if retired or not menu then return end
            -- Release the manager before snapshotting game cursor flags.
            local loader=rawget(_G,'LiveLuaLoader')
            if focused and menu.visible and not capture.active and loader and type(loader.close_manager)=='function' then
                local released,why=loader.close_manager()
                if released==false then menu.visible=false;ctx.log('MCM handoff refused: '..tostring(why))end
            elseif focused and menu.visible and not capture.active and loader and type(loader.open_manager)=='function' then
                menu.visible=false;ctx.log('MCM handoff refused: loader lacks safe close_manager API')
            end
            local acquired,reason=capture.sync(menu.visible,focused,input.window())
            if not acquired then menu.visible=false;menu.capture=false;capture.release();ctx.log('Menu closed: '..tostring(reason))end
            menu.advance(dt)
            local w,h=stingray.Gui.resolution();view.draw(menu.compose(w,h))
        end)
        if not ok and not retired and menu then
            ctx.log('MCM frame failed; menu closed safely: '..tostring(err))
            menu.recover()
            if capture then pcall(capture.release)end;if view then pcall(view.release)end
            -- Keep registrations and the F10 listener alive for recovery.
        end
    end,
    on_disable=close,
    on_cleanup_poll=close,
}
