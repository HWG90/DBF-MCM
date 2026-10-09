-- Native driver is injected; no FFI, game pointers, windows or native calls run.
local Native=dofile('src/integrations/native_entry.lua')
local L=Native.layout
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function copy(value)local result={};for key,item in pairs(value)do result[key]=item end;return result end
local function stripped(fn)
    local values={}
    for index=1,64 do local name,value=debug.getupvalue(fn,index);if not name then break end;values[index]={value=value}end
    local loaded=assert(loadstring(string.dump(fn,true)))
    for index,value in ipairs(values)do assert(debug.setupvalue(loaded,index,value.value)~=nil)end
    assert(select(1,debug.getupvalue(loaded,1))=='','fixture did not strip upvalue names')
    return loaded
end
local function fixture(extra_tabs,with_mom)
    local b={phase='closed',screen=0x100000,count=with_mom and 4 or 3,current=2,shown=2,
        labels={0xd876b36e,0x78934e12,0x8c02bd80},owners={},writes=0,verifications=0,snapshot_reads=0,game_counts={},mom_counts={}}
    if with_mom then b.labels[4]=L.template;b.owners[3]='MODS'end
    for index=1,extra_tabs or 0 do b.count=b.count+1;b.labels[b.count]=0x120000+index;b.owners[b.count-1]='HUD '..index end
    function b.verify()b.verifications=b.verifications+1;return not b.bad_build,b.bad_build and 'unsupported game build'or nil end
    function b.escape_menu()return b.phase=='open'and b.screen or nil,b.phase end
    function b.snapshot(screen)
        b.snapshot_reads=b.snapshot_reads+1
        assert(screen==b.screen and b.phase=='open');assert(b.count>=3 and b.count<=8 and b.current<b.count)
        assert(b.labels[1]==0xd876b36e and b.labels[2]==0x78934e12 and b.labels[3]==0x8c02bd80,'native base label changed')
        local labels={};for index=1,b.count do labels[index]=b.labels[index]end
        return {count=b.count,current=b.current,shown=b.shown,labels=labels}
    end
    function b.apply_tabs(screen,labels,current)
        assert(screen==b.screen and b.phase=='open'and #labels<=8)
        b.labels=copy(labels);b.count=#labels;b.current=current;b.writes=b.writes+1
    end
    function b.set_count(screen,value)assert(screen==b.screen);b.count=value;b.writes=b.writes+1 end
    function b.show_text(screen,index)assert(screen==b.screen);b.owners[index]='MCM';b.writes=b.writes+1 end
    function b.owns(screen,index)return screen==b.screen and b.owners[index]=='MCM'end
    function b.restore_selection(screen,index,shown)assert(screen==b.screen);b.current=index;b.shown=shown;b.writes=b.writes+1 end
    local flags={focus=true,cursor=false,clip=true}
    local window={mouse_focus=function()return flags.focus end,show_cursor=function()return flags.cursor end,clip_cursor=function()return flags.clip end}
    local opened=false;local api={is_open=function()return opened end};local env={};local parent
    local game=function(...)
        b.game_counts[#b.game_counts+1]=b.count
        return 'first',nil,'last',select('#',...)
    end
    if with_mom then
        local state=b
        env.ModOptionsMenu={api=1,register_option=function()return state.count end}
        local TAB_BAR,MODS_TAB=1248,3
        local ensure_mods_tab=function(screen)
            assert(screen==state.screen);state.mom_counts[#state.mom_counts+1]=state.count
            if state.fail_mom then error('MOM failure')end
            if state.count==3 then state.labels[4]=L.template;state.count=4;state.owners[3]='MODS';return true end
            return state.count==4 and state.labels[4]==L.template
        end
        local step=function()
            assert(TAB_BAR==L.bar and MODS_TAB==3)
            if state.phase=='open'then assert(ensure_mods_tab(state.screen),'MODS ownership rejected')end
        end
        local previous_update=game
        env.update=function(...)step();return previous_update(...)end
    else env.update=game end
    local entry=Native.new(api,{backend=b,window=window,env=env,focused=function()return b.foreground~=false end,hud_menu=function()return b.hud_menu,b.hud_initializing end,on_open=function(owner)
        assert(owner.validate());parent=owner;opened=true;return true
    end})
    return {entry=entry,b=b,flags=flags,window=window,env=env,api=api,parent=function()return parent end,
        set_open=function(value)opened=value end,open_escape=function()b.phase='open';flags.focus=false;flags.cursor=true;flags.clip=false end}
end

local function hud_menu(f,slot)
    local b=f.b;local Instance={}
    local hud=setmetatable({slot=slot,n={menu_tab_bar=L.bar,menu_tab_count=L.count,menu_tab_stride=L.stride,menu_text_tab=0x120001}},{__index=Instance})
    function Instance:label_is(at,label)
        return self.slot~=nil and at==b.screen+L.bar+L.text+L.stride*self.slot and label==self.n.menu_text_tab and b.labels[self.slot+1]==label and b.owners[self.slot]=='HUD 1'
    end
    function Instance:show_tab(screen,shown)
        assert(screen==b.screen);if self.slot==nil then return end
        local from,to=self.slot,self.slot+1;if not shown then from,to=to,from end
        if b.count==from then b.count=to end
    end
    function Instance:place(screen)
        assert(screen==b.screen)
        if self.slot~=nil and not self:label_is(screen+L.bar+L.text+L.stride*self.slot,self.n.menu_text_tab)then self.slot=nil end
        if self.slot==nil then
            self.slot=b.count;b.count=b.count+1;b.labels[b.count]=self.n.menu_text_tab;b.owners[self.slot]='HUD 1'
        end
        self:show_tab(screen,true)
        return b.count==self.slot+1
    end
    return hud
end

test('construction is inert and unsupported build installs nothing',function()
    local f=fixture(0,true);assert(f.b.verifications==0 and f.b.writes==0)
    f.b.bad_build=true;local original=f.env.update
    local ok,why=f.entry.install();assert(not ok and why=='unsupported game build'and f.env.update==original and f.b.writes==0)
end)

test('MCM adds an owned native tab preserving MODS and multiple HUD tabs',function()
    for _,extra in ipairs({2,3})do
        local f=fixture(extra,true);local original=copy(f.b.labels);local previous_count=f.b.count;assert(f.entry.install())
        f.env.update(.1);assert(f.entry.status().gameplay_baseline)
        f.open_escape();local a,b,c,d=f.env.update(.1,'arg')
        assert(a=='first'and b==nil and c=='last'and d==2,'update values or arguments lost')
        assert(f.b.count==previous_count+1 and f.entry.status().index==previous_count and f.b.owners[3]=='MODS'and f.b.owners[4]=='HUD 1'and f.b.owners[5]=='HUD 2')
        for index=1,previous_count do assert(f.b.labels[index]==original[index],'another owner label was overwritten')end
        assert(f.b.mom_counts[#f.b.mom_counts]==4 and f.b.game_counts[#f.b.game_counts]==previous_count+1,'MODS/game count bridge failed')
        assert(f.entry.close()and f.b.count==previous_count)
    end
end)

test('MOM callback error restores the full native count and reaches caller',function()
    local f=fixture(2,true);assert(f.entry.install());f.env.update();f.open_escape();f.env.update()
    f.b.fail_mom=true;local ok,why=pcall(f.env.update)
    assert(not ok and tostring(why):find('MOM failure',1,true)and f.b.count==7,'MOM error lost or native count stranded')
    f.b.fail_mom=false;assert(f.entry.close())
end)

test('stripped function wrappers and strict anonymous HUD hook shape reach named MOM',function()
    for _,mode in ipairs({'function','hook'})do
        local f=fixture(1,true)
        if mode=='function'then f.env.update=stripped(f.env.update)
        else
            local hook={base=f.env.update,driver={frame=function(inner,...)return inner(...)end}}
            f.env.update=stripped(function(...)return hook.driver.frame(hook.base,...)end)
        end
        assert(f.entry.install());f.env.update();f.open_escape();f.env.update()
        assert(f.b.count==6 and f.entry.status().index==5 and f.b.mom_counts[#f.b.mom_counts]==4 and f.b.game_counts[#f.b.game_counts]==6,'stripped '..mode..' path did not bridge actual MOM')
        assert(f.entry.close()and f.b.count==5)
    end
end)

test('unknown named callback and dispatch wrappers reach authenticated MOM only',function()
    local f=fixture(1,true)
    local callback=f.env.update
    local dispatch=function(...)return callback(...)end
    local func=function(...)return dispatch(...)end
    f.env.update=func
    assert(f.entry.install());f.env.update();f.open_escape();f.env.update()
    assert(f.b.count==6 and f.entry.status().index==5 and f.b.mom_counts[#f.b.mom_counts]==4 and f.b.game_counts[#f.b.game_counts]==6,'unknown function-edge names hid MOM')
    assert(f.entry.close()and f.b.count==5)
end)

test('matching constants on foreign MOM state do not authorize a callback rewrite',function()
    local f=fixture(0,true)
    local state={};local TAB_BAR,MODS_TAB=1248,3
    local ensure_mods_tab=function()return state end
    local fake_step=function()assert(TAB_BAR==L.bar and MODS_TAB==3);assert(state);return ensure_mods_tab()end
    f.env.update=fake_step
    local original=ensure_mods_tab
    assert(f.entry.install());f.entry.step();f.open_escape()
    local ok,why=f.entry.step();assert(not ok and why=='Waiting for cooperative MODS tab owner'and f.b.writes==0)
    local found
    for index=1,64 do local name,value=debug.getupvalue(fake_step,index);if not name then break end;if name=='ensure_mods_tab'then found=value end end
    assert(found==original,'foreign callback was patched');assert(f.entry.close())
end)

test('deep stripped chains are bounded and stripped API state is never guessed',function()
    local f=fixture(0,true)
    local function wrap(inner)return function(...)return inner(...)end end
    for index=1,40 do f.env.update=stripped(wrap(f.env.update))end
    assert(f.entry.install());f.entry.step();f.open_escape()
    local ok,why=f.entry.step();assert(not ok and why=='Waiting for cooperative MODS tab owner'and f.b.writes==0)
    assert(f.entry.close())
    f=fixture(0,true);f.env.ModOptionsMenu.register_option=stripped(f.env.ModOptionsMenu.register_option)
    assert(f.entry.install());f.entry.step();f.open_escape();ok,why=f.entry.step()
    assert(not ok and why=='Waiting for cooperative MODS tab owner'and f.b.writes==0,'anonymous API state was guessed')
    assert(f.entry.close())
end)

test('initial HUD owner waits without starving gameplay baseline and publishes MCM after real placement',function()
    local f=fixture(0,true);f.b.hud_initializing=true
    assert(f.entry.install());assert(f.entry.step()and f.entry.status().gameplay_baseline,'initializing HUD starved closed-stack baseline')
    f.open_escape();local reads=f.b.snapshot_reads
    local ok,why=f.entry.step();assert(not ok and why=='Waiting for native HUD+ tab placement'and f.b.snapshot_reads==reads and f.b.writes==0)
    local hud=hud_menu(f,nil);f.b.hud_menu=hud
    ok=f.entry.step();assert(not ok and f.b.snapshot_reads==reads and f.b.writes==0,'unplaced HUD permitted MCM publication')
    assert(hud:place(f.b.screen)and hud.slot==4 and f.entry.status().index==5 and f.b.count==6)
    -- A new Escape screen cannot inherit the old HUD/MCM slot ownership.
    f.b.screen=f.b.screen+0x10000;f.b.count=4;f.b.current=2
    f.b.labels={0xd876b36e,0x78934e12,0x8c02bd80,L.template};f.b.owners={[3]='MODS'}
    reads=f.b.snapshot_reads;ok=f.entry.step()
    assert(not ok and f.entry.status().index==nil and f.b.snapshot_reads==reads,'stale screen slot triggered a snapshot/publication')
    assert(hud:place(f.b.screen)and f.b.count==6 and f.entry.status().index==5)
    assert(f.entry.close())
end)

test('outer HUD before can hide selected initial slot until place restores it before MCM snapshots',function()
    local f=fixture(1,true);local hud=hud_menu(f,4);f.b.hud_menu=hud;f.b.hud_initializing=true
    assert(f.entry.install());f.entry.step();local inner=f.env.update
    f.env.update=function(...)
        if f.b.phase=='open'then hud:show_tab(f.b.screen,false)end
        local a,b,c,d=inner(...)
        if f.b.phase=='open'then assert(hud:place(f.b.screen))end
        return a,b,c,d
    end
    f.open_escape();f.b.current=4
    local a,b,c=f.env.update()
    assert(a=='first'and b==nil and c=='last'and f.b.game_counts[#f.b.game_counts]==4)
    assert(f.b.count==6 and f.entry.status().index==5 and f.b.mom_counts[#f.b.mom_counts]==4)
    f.env.update();assert(f.b.game_counts[#f.b.game_counts]==6,'full native count not stable after initial publication')
    assert(f.entry.close())
end)

test('verified late HUD keeps its selected native slot visible and its methods restore on cleanup',function()
    local f=fixture(0,true);assert(f.entry.install());f.env.update();f.open_escape();f.env.update()
    assert(f.entry.status().index==4 and f.b.count==5)
    local hud=hud_menu(f,nil);f.b.hud_menu=hud;f.entry.step();assert(hud:place(f.b.screen)and hud.slot==5 and f.b.count==6)
    f.b.current=5;hud:show_tab(f.b.screen,false)
    assert(f.b.count==6,'later selected HUD was hidden outside the visible count')
    f.env.update();assert(f.b.game_counts[#f.b.game_counts]==6 and f.b.mom_counts[#f.b.mom_counts]==4)
    assert(hud:place(f.b.screen)and f.b.count==6)
    assert(f.entry.close()==false,'removing MCM shifted the later HUD index')
    f.b.phase='closed';assert(f.entry.close()and rawget(hud,'place')==nil and rawget(hud,'show_tab')==nil)
end)

test('actual HUD place shape sees its exact count while MODS and Game keep full bar',function()
    local f=fixture(1,true);local b=f.b
    local Instance={};local hud=setmetatable({slot=4,n={menu_tab_bar=L.bar,menu_tab_count=L.count,menu_tab_stride=L.stride,menu_text_tab=b.labels[5]}},{__index=Instance})
    hud.read={u32=function(_,address)assert(address==b.screen+L.bar+L.count);return b.count end}
    function Instance:label_is(_,label)return label==self.n.menu_text_tab and b.owners[self.slot]=='HUD 1'end
    function Instance:show_tab(screen,shown)
        assert(screen==b.screen);local from,to=self.slot,self.slot+1
        if not shown then from,to=to,from end
        if b.count==from then b.count=to end
    end
    function Instance:place(screen)
        assert(screen==b.screen)
        if b.fail_hud then error('HUD place failure')end
        self:show_tab(screen,true);b.hud_count=b.count
        return self.read:u32(screen+self.n.menu_tab_bar+self.n.menu_tab_count)==self.slot+1,nil,'HUD result'
    end
    b.hud_menu=hud
    -- BootState's published callback can expose only hook.driver.frame/base.
    local hook={base=f.env.update,driver={}}
    local function run(method,...)return method(...)end
    local function finish(...)
        if b.phase=='open'then assert(run(hud.place,hud,b.screen))end
        return ...
    end
    hook.driver.frame=function(inner,...)
        if b.phase=='open'then hud:show_tab(b.screen,false)end
        return finish(inner(...))
    end
    f.env.update=function(...)return hook.driver.frame(hook.base,...)end
    assert(f.entry.install());f.env.update();assert(rawget(hud,'place')~=nil)
    f.open_escape();local a,empty,c=f.env.update();f.env.update()
    assert(a=='first'and empty==nil and c=='last')
    assert(b.count==6 and b.hud_count==5 and b.mom_counts[#b.mom_counts]==4 and b.game_counts[#b.game_counts]==6)
    b.fail_hud=true;local okay,why=pcall(hud.place,hud,b.screen)
    assert(not okay and tostring(why):find('HUD place failure',1,true)and b.count==6,'HUD exception stranded masked count')
    b.fail_hud=false;assert(f.entry.close()and rawget(hud,'place')==nil and b.count==5,'HUD metatable method was not restored')
end)

test('opening requires observed gameplay baseline and returns a real native parent',function()
    local f=fixture(1,true);assert(f.entry.install());f.open_escape();f.env.update()
    f.b.current=f.entry.status().index
    local ok,why=f.entry.step();assert(not ok and why=='Gameplay cursor baseline unavailable'and not f.parent())
    f.b.phase='closed';f.flags.focus=true;f.flags.cursor=false;assert(f.entry.step())
    f.open_escape();f.b.count=5;f.b.labels[6]=nil;f.b.current=4;assert(f.entry.step())
    local index=f.entry.status().index;f.b.current=index;assert(f.entry.step())
    local owner=assert(f.parent());assert(owner.validate()and owner.status().current_owned)
    assert(owner.restoration_snapshot.focus==false and owner.restoration_snapshot.cursor==true,'native Escape flags were fabricated')
    assert(owner.gameplay_snapshot.focus==true and owner.gameplay_snapshot.cursor==false and owner.previous_index==4)
    f.b.phase='covered';assert(not owner.validate()and owner.status().covered);assert(owner.on_close()==false)
    f.b.phase='open';assert(owner.on_close()and f.b.current==4 and not owner.active)
    f.set_open(false);assert(f.entry.close())
end)

test('cursor baseline is not cached from another owner or an open MCM',function()
    local f=fixture(0,false);assert(f.entry.install())
    f.b.foreground=false;f.entry.step();assert(not f.entry.status().gameplay_baseline,'background window state was cached')
    f.b.foreground=true;f.flags.focus=false;f.entry.step();assert(not f.entry.status().gameplay_baseline)
    f.flags.focus=true;f.flags.cursor=true;f.entry.step();assert(not f.entry.status().gameplay_baseline)
    f.flags.cursor=false;f.set_open(true);f.entry.step();assert(not f.entry.status().gameplay_baseline)
    f.set_open(false);f.entry.step();assert(f.entry.status().gameplay_baseline);assert(f.entry.close())
end)

test('a replacement Escape owner releases DLL input but retains pending flags until the actual stack closes',function()
    local f=fixture(1,true);assert(f.entry.install());f.env.update();f.open_escape();f.env.update()
    f.b.current=f.entry.status().index;assert(f.entry.step());local parent=assert(f.parent())
    for _,field in ipairs({{'set_mouse_focus','focus'},{'set_show_cursor','cursor'},{'set_clip_cursor','clip'}})do
        local method,key=field[1],field[2];f.window[method]=function(value)f.flags[key]=value end
    end
    local gate=0
    local native={mcm_install=function()return 1 end,mcm_capture=function(value)gate=value;return 1 end,mcm_captured=function()return gate end,mcm_release=function()gate=0 end}
    local Capture=dofile('src/capture.lua');local capture=Capture.new(native,f.window,function()end)
    assert(capture.sync(true,true,1,parent)and gate==1 and capture.active)
    local before=copy(f.flags)
    f.b.screen=f.b.screen+0x10000
    local status=parent.status();assert(status.replaced and status.covered and not status.closed and not status.open)
    local ok,why=capture.sync(true,true,1,parent)
    assert(not ok and gate==0 and not capture.active and capture.status().pending_restore,'replacement owner did not retain pending restoration')
    for key,value in pairs(before)do assert(f.flags[key]==value,'replacement owner cursor flag changed: '..key)end
    assert(parent.on_close()==false and parent.active,'replacement native owner was treated as closed')
    f.b.phase='closed';assert(parent.status().closed)
    assert(capture.sync(false,true,1,parent)and not capture.status().pending_restore and gate==0)
    assert(f.flags.focus==true and f.flags.cursor==false and f.flags.clip==true,'actual stack close did not restore the observed gameplay baseline')
    assert(not parent.active and f.entry.close())
end)

test('native capacity and base labels are checked before writes',function()
    local f=fixture(4,true);assert(f.entry.install());f.entry.step();f.open_escape()
    local ok,why=f.entry.step();assert(not ok and why=='Native tab bar is full'and f.b.writes==0)
    f.b.labels[1]=0;ok=pcall(f.entry.step);assert(not ok and f.b.writes==0)
    f.b.phase='closed';assert(f.entry.close())
end)

test('cleanup waits under covered native UI and preserves changed peer labels',function()
    local f=fixture(1,true);assert(f.entry.install());f.env.update();f.open_escape();f.env.update()
    f.b.phase='covered';local writes=f.b.writes;assert(f.entry.close()==false and f.b.writes==writes and not f.entry.status().retired)
    f.b.phase='open';f.b.labels[5]=0x123456;assert(f.entry.close()and f.b.count==5 and f.b.labels[5]==0x123456)
end)

test('a later tab owner blocks removal rather than shifting its fixed native index',function()
    local f=fixture(0,true);assert(f.entry.install());f.env.update();f.open_escape();f.env.update()
    f.b.count=6;f.b.labels[6]=0x765432;f.b.owners[5]='Later HUD'
    local ok,why=f.entry.close();assert(not ok and why:find('follows MCM',1,true)and f.b.count==6 and f.b.owners[5]=='Later HUD')
    f.b.current=4;assert(f.entry.step()==false and not f.parent(),'pending cleanup accepted a new native opening')
    f.b.count=5;f.b.labels[6]=nil;assert(f.entry.close()and f.b.count==4)
end)

test('cleanup preserves newer update wrappers and retired native work becomes inert',function()
    local f=fixture(0,true);local original=f.env.update;assert(f.entry.install());assert(f.entry.install()==false)
    f.env.update();f.open_escape();f.env.update();local previous_update=f.env.update
    local newer=function(...)return previous_update(...)end;f.env.update=newer
    assert(f.entry.close()and f.env.update==newer and f.b.count==4)
    local writes=f.b.writes;local a,b,c=f.env.update('arg')
    assert(a=='first'and b==nil and c=='last'and f.b.writes==writes and f.b.mom_counts[#f.b.mom_counts]==4)
    assert(f.env.update~=original,'newer wrapper was overwritten')
end)

test('real Windows backend verifies prologues and uses native tab/text calls on guarded objects',function()
    local base,ui,menu,screen=0x10000000,0x20000000,0x30000000,0x40000000
    local bytes,calls={},{}
    local function put32(address,value)for index=0,3 do bytes[address+index]=value%256;value=math.floor(value/256)end end
    local function put64(address,value)put32(address,value);put32(address+4,0)end
    local function get32(address)return (bytes[address]or 0)+(bytes[address+1]or 0)*256+(bytes[address+2]or 0)*65536+(bytes[address+3]or 0)*16777216 end
    local function hex(value)return (value:gsub('%x%x',function(pair)return string.char(tonumber(pair,16))end))end
    local signatures={
        [0x17aac50]='\x48\x89\x54\x24\x10\x53\x56\x48\x83\xec\x68\x0f\x29\x74\x24\x30',
        [0x143bf90]='\x48\x83\xec\x28\x4c\x8b\xd9\x39\x91\x10\x01\x00\x00\x0f\x84\x80',
        [0x143c950]='\x40\x53\x48\x83\xec\x20\x48\x8b\xd9\x48\x81\xc1\x10\x01\x00\x00',
        [0x1474370]=hex('48895c2408574883ec508b41088bda488bf9'),
        [0x17abfc0]=hex('48895c240848896c24104889742418574883ec204863816ce00000')}
    assert(#signatures[0x1474370]==18 and #signatures[0x17abfc0]==27)
    -- Only masked displacement/stack bytes differ from the verified reference.
    signatures[0x1474370]=signatures[0x1474370]:sub(1,4)..'\x7f'..signatures[0x1474370]:sub(6)
    signatures[0x17abfc0]=signatures[0x17abfc0]:sub(1,23)..'\x01\x02\x03\x04'
    for index,label in ipairs({0xd876b36e,0x78934e12,0x8c02bd80})do
        put32(base+0x33114d0+(index-1)*4,label);put32(screen+L.bar+L.labels+(index-1)*4,label)
    end
    put64(base+0x347ce28,ui);put64(base+0x347ce38,menu);put64(menu+200,screen)
    put32(ui+0x429c,1);put32(ui+0x429c+20,1)
    put32(screen+L.bar+L.count,3);put32(screen+L.bar+L.current,0);put32(screen+L.shown,0)
    local memory={verify_build=function(build)assert(build.exe_sha256==Native.build.exe_sha256 and build.game_sha256==Native.build.game_sha256);return true end,
        module=function(name)assert(name=='game.dll');return base end,address=function(value)return value end,
        writable_data=function(address,size)return address>=screen and address+size<=screen+L.bar+L.count+8 end,
        read=function(address,size)
            assert(type(address)=='table'and address.read_pointer,'native reader requires a typed pointer')
            address=address.address
            local signature=signatures[address-base];if signature then return signature:sub(1,size)end
            local result={};for offset=0,size-1 do result[#result+1]=string.char(bytes[address+offset]or 0)end;return table.concat(result)
        end}
    local ffi={new=function(kind,size)
        if kind=='char[4]'then assert(size=='MCM');return {address=0x50000000}end
        assert(kind=='uint32_t[8]');return {}
    end,cast=function(kind,address)
        if kind=='uint64_t'then return address.address end
        if kind=='const void *'then return {address=address,read_pointer=true}end
        if kind=='uint32_t *'or kind=='uint8_t *'then
            return setmetatable({},{__newindex=function(_,index,value)
                if kind=='uint32_t *'then put32(address+index*4,value)else bytes[address+index]=value end
            end})
        end
        local rva=address-base
        if rva==0x17aac50 then return function(bar,labels,total)
            calls[#calls+1]='tabs';assert(bar==screen+L.bar and total<=8)
            put32(bar+L.count,total);for index=0,total-1 do put32(bar+L.labels+index*4,labels[index])end
        end end
        if rva==0x143bf90 then return function(widget,label)
            calls[#calls+1]='label';assert(widget==screen+L.bar+L.text+L.stride*3 and label==L.template);put32(widget+L.label,label)
        end end
        if rva==0x143c950 then return function(widget,key,text)
            calls[#calls+1]='string';assert(key==L.key and text.address==0x50000000)
            bytes[widget+L.arg_count]=1;put32(widget+L.args,key);put32(widget+L.args+4,1);put64(widget+L.args+8,text.address)
        end end
        if rva==0x1474370 then
            assert(kind=='void (*)(uintptr_t,int32_t)')
            return function(target,shown)
                assert(target==screen and shown>=0 and shown<=2);calls[#calls+1]='switch';put32(screen+L.shown,shown)
            end
        end
        if rva==0x17abfc0 then
            assert(kind=='void (*)(uintptr_t,int32_t,uint8_t,uint8_t)')
            return function(bar,index,one,two)
                assert(bar==screen+L.bar and index>=0 and index<get32(bar+L.count)and one==0 and two==0)
                assert(calls[#calls]=='switch','native selection did not follow screen content switch')
                calls[#calls+1]='select';put32(bar+L.current,index)
            end
        end
        error('Unexpected native cast')
    end}
    local old_pin=package.loaded['dbf_mcm.native_entry.text.v1'];package.loaded['dbf_mcm.native_entry.text.v1']=nil
    local backend=Native.windows({ffi=ffi,dependencies={runtime={},memory={new=function()return memory end}}})
    assert(#calls==0 and backend.verify())
    local found,status=backend.escape_menu();assert(found==screen and status=='open')
    local snapshot=backend.snapshot(screen);local labels=copy(snapshot.labels);labels[4]=L.template
    backend.apply_tabs(screen,labels,0);backend.show_text(screen,3)
    assert(backend.owns(screen,3)and get32(screen+L.bar+L.count)==4 and table.concat(calls,',')=='tabs,label,string')
    -- Real native calls restore GAME/SOCIAL/OPTIONS and keep MODS/HUD logical indexes.
    put32(screen+L.bar+L.count,8)
    for index=4,7 do put32(screen+L.bar+L.labels+4*index,0x120000+index)end
    local previous_labels={};for index=0,7 do previous_labels[index]=get32(screen+L.bar+L.labels+4*index)end
    for shown=0,2 do for _,index in ipairs({0,1,2,3,4})do
        calls={};put32(screen+L.bar+L.current,7)
        backend.restore_selection(screen,index,shown)
        assert(table.concat(calls,',')=='switch,select'and get32(screen+L.shown)==shown and get32(screen+L.bar+L.current)==index)
        assert(get32(screen+L.bar+L.count)==8,'native restoration changed tab capacity/count')
        for slot=0,7 do assert(get32(screen+L.bar+L.labels+slot*4)==previous_labels[slot],'native restoration changed another tab label')end
    end end
    local good=signatures[0x1474370];signatures[0x1474370]='\x90'..good:sub(2)
    local okay,why=backend.verify();assert(not okay and why=='Native tab_switch signature changed','changed non-masked opcode was accepted')
    signatures[0x1474370]=good;assert(backend.verify())
    put32(ui+0x429c+4,2);put32(ui+0x429c+20,2)
    assert(select(2,backend.escape_menu())=='covered'and not pcall(backend.show_text,screen,3),'covered native object accepted a write')
    package.loaded['dbf_mcm.native_entry.text.v1']=old_pin
end)

print('PASS '..count..' guarded native-entry contracts without raw pointer calls')
