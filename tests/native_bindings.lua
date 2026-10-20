-- Native registry/memory fixtures only; no attachment to the running game.
local Core=dofile('src/core.lua')
local Grouping=dofile('src/grouping.lua')
local Bindings=dofile('src/bindings.lua')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function fixture()
    local state={registry={},order={},build_rows=true};local words={}
    local memory,reads={},{};local fail,changed
    local host={api=1,version=3,capacity=36};local forbidden=0
    local function read_words(address,size)
        reads[#reads+1]={address,size}
        if address==fail then return false end
        local values=memory[address];if not values then return false end
        for index=0,5 do words[index]=values[index+1]or 0 end
        if address==changed then memory[4096][2]=memory[4096][2]+1 end
        return true
    end
    local function live_header(record)
        assert(state.registry[record.id]==record)
        if not read_words(record.bucket,8)or words[0]~=record.code then return end
        return record.bucket,words[1]
    end
    function host.register_binding(id,label,slot,options)
        assert(slot==0 and options.category=='First Person')
        local record={id=id,text=label,category=options.category,group=10,action=6,code=655366,bucket=4096}
        state.registry[id]=record;state.order[#state.order+1]=record
        return true
    end
    function host.is_down(id)
        forbidden=forbidden+1
        -- Keep the real provider's named upvalues, without evaluating actions.
        if state.registry[id]then return live_header(state.registry[id])end
    end
    function host.ready()return state.build_rows~=nil end
    local keyboard={button_name=function()error('Native IDs must not be passed to Stingray Keyboard')end}
    local self={host=host,state=state,memory=memory,reads=reads,keyboard=keyboard}
    function self.mapping(flags,key,trigger,combine,threshold)
        memory[4096]={655366,1};memory[4104]={flags or 67,key or 161,trigger or 0,combine or 0,threshold or 0}
    end
    function self.fail(address)fail=address end
    function self.change_during(address)changed=address end
    function self.assert_read_only()assert(forbidden==0,'lookup evaluated/swept a native action')end
    return self
end
local function setup(f)
    local api=Core.new(nil,function()end,Grouping)
    local compat=dofile('src/compat.lua').new(nil)
    assert(compat.register_option('firstperson.enabled',{mod='FIRST PERSON',type='toggle',label='Enabled',default=true}))
    dofile('src/legacy.lua').new(api,function()end,Core).poll(compat)
    -- Exact registration used by the supplied First Person ZIP.
    assert(f.host.register_binding('firstperson.toggle','Toggle First Person',0,{category='First Person'}))
    local bridge=Bindings.new(api,function()end,{keyboard=f.keyboard})
    bridge.poll(f.host,'FIRST PERSON')
    return api,bridge,compat
end
local function page(api)
    local mods=api.list();assert(#mods==1 and mods[1].name=='FIRST PERSON')
    assert(#mods[1].pages==2 and mods[1].pages[2].name=='Keybindings')
    assert(mods[1].pages[2].native_binding_category=='FIRST PERSON')
    return mods[1].pages[2]
end
test('First Person native registration appears under its existing options',function()
    local f=fixture();f.mapping();local api,bridge,compat=setup(f)
    local p=page(api);assert(p.controls[2].label=='Toggle First Person')
    assert(p.controls[2].native_binding_value=='F1')
    assert(compat.get('firstperson.enabled')==true)
    local Menu=dofile('src/menu.lua');local menu=Menu.new(api);menu.visible=true;menu.page=2
    local seen={};for _,command in ipairs(menu.compose(1920,1080))do if command.type=='text'then seen[command.text]=true end end
    assert(seen.Keybindings and seen['Toggle First Person']and seen.F1)
    f.assert_read_only();assert(bridge.diagnostic():find('imported=1',1,true))
end)
test('lookup refreshes native remaps without rewriting values or registry',function()
    local f=fixture();f.mapping();local api,bridge=setup(f);local record=f.state.registry['firstperson.toggle']
    local register,is_down=f.host.register_binding,f.host.is_down
    f.memory[4096][2]=0;bridge.poll(f.host,'First Person');assert(page(api).controls[2].native_binding_value=='Not bound')
    f.mapping(67,0xABCD00A1);bridge.poll(f.host,'FIRST PERSON')
    assert(page(api).controls[2].native_binding_value=='F1','parser garbage was treated as key ID')
    assert(f.memory[4104][2]==0xABCD00A1 and f.state.registry['firstperson.toggle']==record)
    assert(f.host.register_binding==register and f.host.is_down==is_down);f.assert_read_only()
end)
test('all native mappings and unknown trigger/device data remain visible',function()
    local f=fixture();f.mapping();f.memory[4096][2]=2
    f.memory[4124]={64+8*65536,5,8,17,0x3F800000}
    local api=setup(f);local label=page(api).controls[2].native_binding_value
    assert(label:find('F1',1,true))
    assert(label:find('Other input binding (Custom trigger)',1,true))
    assert(not label:find('Threshold',1,true)and not label:find('0x',1,true))
    local snapshot=page(api).controls[2].native_binding_snapshot
    assert(snapshot[2].combine==17 and snapshot[2].threshold_bits==0x3F800000)
    f.assert_read_only()
end)
test('failed reads, invalid counts and changing headers never say not bound',function()
    local f=fixture();f.mapping();local api,bridge=setup(f)
    f.fail(4104);bridge.poll(f.host,'FIRST PERSON');assert(page(api).controls[2].native_binding_value=='Unavailable')
    f.fail(nil);f.memory[4096][2]=17;bridge.poll(f.host,'FIRST PERSON')
    assert(page(api).controls[2].native_binding_value=='Unavailable')
    f.mapping();f.change_during(4104);bridge.poll(f.host,'FIRST PERSON')
    assert(page(api).controls[2].native_binding_value=='Unavailable')
    f.assert_read_only()
end)
test('native reads occur only for the visible binding category',function()
    local f=fixture();f.mapping();local api,bridge=setup(f);local before=#f.reads
    bridge.poll(f.host);bridge.poll(f.host,'Other');assert(#f.reads==before)
    f.state.build_rows=nil;bridge.poll(f.host,'FIRST PERSON')
    assert(page(api).controls[2].native_binding_value=='Unavailable')
end)
test('late registration, host loss and replacement preserve existing settings',function()
    local f=fixture();f.mapping();local api,bridge,compat=setup(f)
    assert(compat.set('firstperson.enabled',false));bridge.poll(nil)
    assert(#api.list()[1].pages==1 and compat.get('firstperson.enabled')==false)
    local next_f=fixture();next_f.mapping();assert(next_f.host.register_binding('firstperson.toggle','Toggle First Person',0,{category='First Person'}))
    bridge.poll(next_f.host,'FIRST PERSON');assert(page(api).controls[2].native_binding_value=='F1')
    next_f.state.registry['firstperson.toggle'].text='Toggle view';bridge.poll(next_f.host,'FIRST PERSON')
    assert(page(api).controls[2].label=='Toggle view')
    bridge.release();assert(#api.list()[1].pages==1 and compat.get('firstperson.enabled')==false)
end)
test('numeric localization and oversized native IDs remain safe display text',function()
    local f=fixture();f.mapping();local api,bridge=setup(f)
    local record=f.state.registry['firstperson.toggle'];f.state.registry[record.id]=nil
    record.id=string.rep('x',600)..'\1';record.text=nil;record.label=1234
    f.state.registry[record.id]=record;bridge.poll(f.host,'FIRST PERSON')
    assert(page(api).controls[2].label=='Native Binding')
    assert(page(api).controls[2].native_binding_value=='F1');f.assert_read_only()
end)
test('ship-station native IDs use verified names rather than Stingray VK labels',function()
    local f=fixture();f.mapping();local api,bridge=setup(f)
    local record=f.state.registry['firstperson.toggle']
    for _,entry in ipairs({{58,'Tab'},{161,'F1'},{165,'F5'},{166,'F6'},{167,'F7'},{168,'F8'}})do
        f.mapping(67,entry[1],0,0,0x3E4CCCCD);bridge.poll(f.host,'FIRST PERSON')
        assert(page(api).controls[2].native_binding_value==entry[2])
        assert(f.memory[4104][2]==entry[1] and f.memory[4104][5]==0x3E4CCCCD)
    end
    record.text=nil;record.label=0x19e97f02;bridge.poll(f.host,'FIRST PERSON')
    assert(page(api).controls[2].label=='Armory')
    f.mapping(67,124);bridge.poll(f.host,'FIRST PERSON')
    assert(page(api).controls[2].native_binding_value=='Unknown keyboard key','An unverified native ID was mislabeled F13 again')
    f.assert_read_only()
end)
test('native rows are selectable read-only fields and do not invoke settings handlers',function()
    local f=fixture();f.mapping();local api,bridge=setup(f)
    local Menu=dofile('src/menu.lua');local menu=Menu.new(api);menu.visible=true;menu.page=2;menu.focus='settings'
    menu.key(13);assert(not menu.capture and not menu.text_edit and not menu.dropdown)
    assert(menu.notice:find('Rebind in Options',1,true))
    menu.key(39);menu.key(9);assert(f.memory[4104][2]==161)
    local commands=menu.compose(1920,1080);local field
    for _,command in ipairs(commands)do if command.native_binding_id=='firstperson.toggle'then field=command end end
    assert(field and field.full_text=='F1' and field.text_bounds.w>0)
    for _,command in ipairs(commands)do if command.type=='text'then
        assert(not command.text:find('Threshold',1,true)and not command.text:find('cowboybingus.',1,true))
        assert(command.text~='Right click for setting options','Read-only MBM page advertised editable settings')
    end end
    assert(page(api).controls[2].description:find('Mod Bindings Menu owns this binding',1,true));f.assert_read_only()
end)
test('standalone groups avoid repeated Keybindings suffix and mount when an owner arrives',function()
    local f=fixture();f.mapping();assert(f.host.register_binding('firstperson.toggle','Toggle First Person',0,{category='First Person'}))
    local api=Core.new(nil,function()end,Grouping);local bridge=Bindings.new(api,function()end)
    bridge.poll(f.host,'FIRST PERSON');assert(#api.list()==1 and api.list()[1].name=='FIRST PERSON')
    api.register({id='parent',name='First Person',pages={{id='settings',name='Settings',controls={}}}})
    bridge.poll(f.host,'FIRST PERSON');assert(#api.list()==1 and api.list()[1].name=='First Person')
    assert(#api.list()[1].pages==2 and api.list()[1].pages[2].name=='Keybindings')
end)
test('absent, unsupported and unrelated private registries fail closed',function()
    local api=Core.new();local bridge=Bindings.new(api);bridge.poll(nil,true);assert(#api.list()==0)
    local f=fixture();f.mapping();f.host.version=2;bridge.poll(f.host,true);assert(#api.list()==0)
    f.host.version=3;f.host.register_binding=function()return true end;bridge.poll(f.host,true);assert(#api.list()==0)
    local g=fixture();g.mapping();assert(g.host.register_binding('firstperson.toggle','Toggle First Person',0,{category='First Person'}))
    g.state.registry['firstperson.toggle'].code=99;bridge.poll(g.host,true);assert(#api.list()==0)
    f.assert_read_only();g.assert_read_only()
end)
test('mounted imported rows capture through the editor and refresh the native readout',function()
    local f=fixture();f.mapping();local api,old,compat=setup(f);old.release()
    local writes=0;local editor={poll=function(host,records)assert(host==f.host and #records==1)end,
        available=function(record)return record==f.state.registry['firstperson.toggle']end,
        bind=function(record,vk)assert(vk==113 and record==f.state.registry['firstperson.toggle']);writes=writes+1;f.memory[4104][2]=162;return true,'Binding saved'end,
        release=function()end}
    local bridge=Bindings.new(api,function()end,{editor=editor,key_name=function(code)return code==162 and 'F2'or 'F1'end})
    bridge.poll(f.host,'FIRST PERSON')
    local Menu=dofile('src/menu.lua');local menu=Menu.new(api);menu.visible=true;menu.focus='settings';menu.page=2
    menu.key(13);assert(menu.capture and menu.capture.native_binding_id=='firstperson.toggle')
    menu.key(113);assert(writes==1 and not menu.capture and menu.notice=='Binding saved')
    assert(page(api).controls[2].native_binding_value=='F2'and compat.get('firstperson.enabled')==true)
    f.assert_read_only();bridge.release()
end)
print(count..' native-binding lookup regressions passed; live game readback remains unverified')

local f=fixture();f.host.version=4
f.host.register_binding('firstperson.toggle','Toggle First Person',0,{category='First Person'})
f.mapping();local record={id='dbf.next',text='Next stratagem',category='DBF',extended=true}
f.state.registry[record.id]=record;f.state.extended_order={record}
f.host.binding=function(id)assert(id==record.id);return{{device='mouse',button='wheel_down',trigger='press'}}end
local api=Core.new(nil,function()end,Grouping);local bridge=Bindings.new(api)
bridge.poll(f.host,true);assert(bridge.diagnostic():find('imported=2',1,true))
local found=false;for _,mod in pairs(api.mods)do for _,p in ipairs(mod.pages)do for _,c in ipairs(p.controls)do if c.native_binding_id=='dbf.next'then assert(c.native_binding_value=='mouse wheel_down (press)');found=true end end end end
assert(found);bridge.release();print('MBM v4 native plus extended mouse bindings imported')

for _,version in ipairs({3,4,5,99})do
 local f=fixture();f.mapping();local api=setup(f);f.host.version=version
 local bridge=Bindings.new(api);bridge.poll(f.host,true)
 assert(#api.list()>0,'MBM version '..version..' should be accepted');f.assert_read_only()
end
print('PASS MBM v3 and newer importer compatibility')
