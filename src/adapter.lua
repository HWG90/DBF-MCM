local api,menu,view,registered,input,log,capture;local legacy;local binding_host;local held_toggle=false;local retired=false
local function close()
    if legacy then legacy.release();legacy=nil end
    retired=true;if registered then registered.unregister();registered=nil end
    if capture then capture.release();capture=nil end
    if view then view.release();view=nil end
    if api and rawget(_G,'DBFMCM')==api then rawset(_G,'DBFMCM',nil)end
    api,menu,input=nil,nil,nil;binding_host=nil;held_toggle=false
end
return {
    name='Mod Configuration Menu (Preview)',version='0.1.24',author='Local development',
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
        api=MCM.core.new(MCM.store.new(folder),ctx.log);menu=MCM.menu.new(api);view=MCM.view.new(sr)
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
        function api.open()menu.visible=true end
        function api.close()menu.visible=false end
        function api.is_open()return menu.visible end
        ctx.global('DBFMCM',api)
        legacy=MCM.legacy.new(api,ctx.log,MCM.core)
        registered=api.register({id='mcm',name='Mod Configuration Menu',description='Shared mod configuration framework.',pages={
            {id='overview',name='Overview',controls={
                {type='section',label='AUTHOR FRAMEWORK'},
                {type='text',label='Register mods through DBFMCM.register.'},
                {type='text',label='Mod list and pages scroll independently.'},
                {type='text',label='Settings persist outside your savegame.'},
                {type='text',label='Window keyboard/mouse capture while open.'}}},
            {id='controls',name='Control showcase',controls={
                {id='enabled',type='toggle',label='Example toggle',default=true,description='A persistent on/off setting.'},
                {id='color',type='color',label='Example color',default='#F4CA35',description='RGB and HEX input with a preview swatch.'},
                {id='amount',type='slider',label='Example slider',min=0,max=100,step=5,default=50,description='Left and right change the value; Home restores the default.'},
                {id='style',type='choice',label='Example choice',choices={'Standard','Compact','Wide'},default=1,description='Click or press left/right to cycle choices.'},
                {id='name',type='input',label='Example name',default='My preset',max_length=80,description='Text saves on Enter, Tab, or leaving the field; Escape cancels.'},
                {id='key',type='keybind',label='Example key binding',default=0,description='Select, then press a key; Escape cancels. This stores a key code; the mod handles the action.'},
                {id='action',type='button',label='Example action',description='A callback button; not a persisted setting.',on_activate=function()ctx.log('MCM example action activated')end}}}}})
        ctx.log('MCM preview enabled; F10 opens the menu. Existing Mod Options Menu is unchanged.')
    end,
    on_update=function(ctx,dt)
        if retired or not api then return end
        local ok,err=pcall(function()
            input.poll()
            legacy.poll(rawget(_G,'ModOptionsMenu'))
            -- Native binding action aliases can collide with game menu navigation.
            -- Use the physical F10 edge until an independent action is verified.
            menu.tick(input)
            if menu.visible and not input.focused()then menu.visible=false;menu.capture=false end
            local acquired,reason=capture.sync(menu.visible,input.focused(),input.window())
            if not acquired then menu.visible=false;menu.capture=false;capture.release();ctx.log('Menu closed: '..tostring(reason))end
            local w,h=stingray.Gui.resolution();view.draw(menu.compose(w,h))
        end)
        if not ok then ctx.log('MCM stopped after error: '..tostring(err));close()end
    end,
    on_disable=close,
}
