-- Frontend contracts run in isolated Lua state; no native input or game writes.
local Core=dofile('src/core.lua')
local Grouping=dofile('src/grouping.lua')
local Menu=dofile('src/menu.lua')
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local function fixture(mounted)
    local writes,commits=0,{}
    local available,available_reason=true,nil
    local fail,throw=false,false
    local api=Core.new({load=function()return {}end,save=function()writes=writes+1;return true end},nil,mounted and Grouping or nil)
    if mounted then assert(api.register({id='parent',name='First Person',pages={{id='settings',name='Settings',controls={}}}}))end
    local binding={id='native_toggle',type='text',label='Toggle First Person',text_role='selection',native_binding_id='firstperson.toggle',native_binding_value='F1',
        native_binding_available=function()if throw=='availability'then error('provider check failed')end;return available,available_reason end,
        native_binding_bind=function(vk)
            if throw=='bind'then error('provider write failed')end
            if fail then return false,'Save refused'end
            commits[#commits+1]=vk;return true,'Binding saved'
        end}
    local handle=assert(api.register({id='bindings',name=mounted and 'Native Bindings' or 'First Person',parent_name=mounted and 'First Person' or nil,
        pages={{id='keybindings',name='Keybindings',require_confirmation=false,controls={binding}}}}))
    local source=api.mods.bindings;source.pages[1].native_binding_category='FIRST PERSON'
    local setting_writes=0
    handle.edit=function()setting_writes=setting_writes+1;error('Native rows must not edit MCM settings')end
    handle.set=function()setting_writes=setting_writes+1;error('Native rows must not set MCM settings')end
    local menu=Menu.new(api);menu.visible=true;menu.focus='settings';menu.page=mounted and 2 or 1
    local self={api=api,menu=menu,source=source,handle=handle,control=source.pages[1].controls[1],commits=commits}
    function self.available(value,why)available,available_reason=value,why end
    function self.fail(value)fail=value end
    function self.throw(value)throw=value end
    function self.clean()assert(writes==0 and setting_writes==0,'Native editor wrote an MCM setting or its storage')end
    return self
end
local function field(menu,value)
    for _,command in ipairs(menu.compose(1920,1080))do
        if command.native_binding_id=='firstperson.toggle'and(not value or command.full_text==value)then return command end
    end
    error('Missing native binding field '..tostring(value))
end
test('ordinary keybind unbind stages and applies zero with a readable label',function()
    local saved={}
    local api=Core.new({load=function()return {}end,save=function(_,v)saved=v;return true end})
    local h=api.register({id='ordinary',name='Ordinary',pages={{id='settings',name='Settings',require_confirmation=true,controls={{id='key',type='keybind',label='Shortcut',default=112}}}}})
    local mod=api.mods.ordinary;local page=mod.pages[1];local menu=Menu.new(api);menu.visible=true;menu.compose(1920,1080)
    menu.open_context({kind='control',mod=mod,page=page,control=page.controls[1]},100,100)
    local found
    for i,item in ipairs(menu.context_menu.items)do if item.label=='Unbind key'then found=i end end
    assert(found and menu.run_context(found))
    assert(h.preview('key')==0 and h.get('key')==112)
    assert(menu.apply_page(mod,page));assert(h.get('key')==0)
    assert(Menu.key_name(0)=='Not bound')
end)
test('context unbind clears native keyboard binding through guarded callback',function()
    local f=fixture();f.menu.compose(1920,1080)
    assert(f.menu.open_context({kind='control',mod=f.source,page=f.source.pages[1],control=f.control},100,100))
    local found
    for i,item in ipairs(f.menu.context_menu.items)do if item.label=='Unbind key'then found=i;assert(item.enabled)end end
    assert(found and f.menu.run_context(found))
    assert(f.commits[1]==0 and not f.menu.capture);f.clean()
end)
test('Enter captures a native key and saves through its callback only',function()
    local f=fixture();f.menu.key(13);assert(f.menu.capture==f.control)
    assert(field(f.menu,'Press a key'));f.menu.key(113)
    assert(#f.commits==1 and f.commits[1]==113 and not f.menu.capture and f.menu.notice=='Binding saved')
    f.clean()
end)
test('clicking the compact field begins native capture',function()
    local f=fixture();local command=field(f.menu,'F1')
    f.menu.tick({down=function(vk)return vk==1 end,mouse=function()return command.x+2,command.y end})
    assert(f.menu.capture==f.control and f.menu.focus=='settings')
    f.menu.key(116);assert(f.commits[1]==116 and not f.menu.capture);f.clean()
end)
test('failed native saves and exceptions retain the editor for retry',function()
    local f=fixture();f.fail(true);f.menu.key(13);f.menu.key(113)
    assert(f.menu.capture and #f.commits==0 and f.menu.notice:find('Save refused',1,true))
    f.fail(false);f.throw('bind');f.menu.key(114)
    assert(f.menu.capture and #f.commits==0 and f.menu.notice:find('provider write failed',1,true))
    f.throw(false);f.menu.key(115);assert(f.commits[1]==115 and not f.menu.capture);f.clean()
end)
test('Escape cancels without closing MCM or mutating a binding',function()
    local f=fixture();f.menu.key(13);f.menu.key(27)
    assert(not f.menu.capture and f.menu.visible and #f.commits==0 and f.menu.notice=='Binding cancelled');f.clean()
end)
test('unsupported or throwing providers remain read-only',function()
    local f=fixture();f.available(false,'Native rebinding unavailable');f.menu.key(13)
    assert(not f.menu.capture and f.menu.notice=='Native rebinding unavailable')
    f.throw('availability');f.menu.key(13)
    assert(not f.menu.capture and f.menu.notice:find('provider check failed',1,true))
    f.control.native_binding_available=nil;f.menu.key(13)
    assert(not f.menu.capture and f.menu.notice:find('Rebind in Options',1,true));f.clean()
end)
test('provider loss during capture cancels before invoking its setter',function()
    local f=fixture();f.menu.key(13);f.available(false,'Provider stopped');f.menu.key(113)
    assert(not f.menu.capture and #f.commits==0 and f.menu.notice=='Provider stopped');f.clean()
end)
test('unregistered owners and replaced source controls cancel capture',function()
    local f=fixture();f.menu.key(13);f.handle.unregister();f.menu.key(113)
    assert(not f.menu.capture and #f.commits==0);f.clean()
    f=fixture();f.menu.key(13);f.source.pages[1].controls[1]={type='text',label='Replacement'};f.menu.key(113)
    assert(not f.menu.capture and #f.commits==0);f.clean()
end)
test('replaced callbacks and changed focus never receive a captured key',function()
    local f=fixture();f.menu.key(13);f.control.native_binding_bind=function()error('Replacement received stale capture')end;f.menu.key(113)
    assert(not f.menu.capture and #f.commits==0);f.clean()
    f=fixture();f.menu.key(13);f.menu.focus='mods';f.menu.key(113)
    assert(not f.menu.capture and #f.commits==0);f.clean()
    f=fixture();f.menu.key(13);f.menu.input_focus(false,{down=function()return false end});f.menu.key(113)
    assert(not f.menu.capture and #f.commits==0);f.clean()
end)
test('mounted native rows survive presentation copies and retain source identity',function()
    local f=fixture(true);field(f.menu,'F1');f.menu.key(13);assert(f.menu.capture)
    field(f.menu,'Press a key');f.menu.key(113)
    assert(f.commits[1]==113 and not f.menu.capture);f.clean()
    f=fixture(true);f.menu.key(13);f.api.mods.parent=nil;f.menu.key(113)
    assert(not f.menu.capture and #f.commits==0);f.clean()
end)
test('native arrows do not begin capture and standard keybinds still save normally',function()
    local f=fixture();f.menu.key(39);assert(not f.menu.capture and #f.commits==0);f.clean()
    local api=Core.new();local handle=assert(api.register({id='normal',name='Normal',pages={{id='settings',name='Settings',require_confirmation=false,
        controls={{id='key',type='keybind',label='Shortcut',default=112}}}}}))
    local menu=Menu.new(api);menu.visible=true;menu.focus='settings';menu.key(13);assert(menu.capture)
    menu.key(113);assert(not menu.capture and handle.get('key')==113)
end)
print('PASS '..passed..' native binding editor contracts; live capture and persistence remain unverified')
