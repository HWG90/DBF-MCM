local api,menu,view,registered,input,log,capture;local legacy;local diagnostic;local binding_host;local held_toggle=false;local retired=false
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
    api,menu,input=nil,nil,nil;binding_host=nil;held_toggle=false
end
return {
    name='Mod Configuration Menu (Preview)',version='0.1.50',author='Local development',
    description='Independent MCM-style author framework. F10 opens a keyboard/mouse preview. Not yet a native pause-menu replacement.',
    on_enable=function(ctx)
        assert(ctx.api==2 and type(ctx.global)=='function' and type(ctx.on_cleanup)=='function','MDL API 2 required')
        assert(not rawget(_G,'DBFMCM'),'Another DBFMCM instance is active')
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
        local sr=assert(rawget(_G,'stingray'),'Stingray unavailable');log=ctx.log;retired=false
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
        api=MCM.core.new(storage,ctx.log,MCM.grouping);MCM.authoring.install(api);view=MCM.view.new(sr,nil,ctx.log);menu=MCM.menu.new(api,view.measure)
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
        function api.open()menu.visible=true end
        function api.close()
            menu.visible=false;menu.capture=false
            if capture then capture.release()end
            if view then view.release()end
        end
        function api.is_open()return menu.visible end
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
            menu.tick(input)
            if retired or not menu then return end
            if menu.visible and not input.focused()then menu.visible=false;menu.capture=false end
            local acquired,reason=capture.sync(menu.visible,input.focused(),input.window())
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
