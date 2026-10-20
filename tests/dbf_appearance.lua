local Core=dofile('src/core.lua');local Compat=dofile('src/compat.lua');local Legacy=dofile('src/legacy.lua')
local api=Core.new(nil,function()end);local host=Compat.new(nil)
for _,spec in ipairs({{'enabled','Selection / Enable','toggle',true},{'cooldown_timers','Appearance / Show cooldown timers','toggle',true},{'dock_gap','Appearance / Dock gap','slider',6},{'selection_mode_ordered','Selection / Mode','choice',1}})do
 local o={mod="Diver's Best Friend",type=spec[3],label=spec[2],default=spec[4],min=0,max=80,step=2,choices={'Wedge Wheel','List Select','Native wheel'}}
 assert(host.register_option('native_stratagem_radial.'..spec[1],o))
end
assert(host.register_option('native_stratagem_radial.full_color_icons',{mod="Diver's Best Friend",type='toggle',label='Appearance / Full-color stratagem icons',default=false}))
assert(host.register_option('native_stratagem_radial.experimental_layout',{mod="Diver's Best Friend",type='choice',label='Appearance / Wedge Wheel layout',default=2,choices={'Cards','Expanded'}}))
assert(host.register_option('native_stratagem_radial.input_interval_ms',{mod="Diver's Best Friend",type='slider',label='Advanced / Input interval',default=70,min=0,max=250,step=5}))
assert(host.register_option('native_stratagem_radial.randomize_input_delay',{mod="Diver's Best Friend",type='toggle',label='Advanced / Randomize input delay',default=false}))
for _,key in ipairs({'hide_sos','hide_eagle_rearm'})do
 assert(host.register_option('native_stratagem_radial.'..key,{mod="Diver's Best Friend",type='toggle',label='Blacklist '..key,default=true}))
end
local bridge=Legacy.new(api,function()end,Core);bridge.poll(host)
local mod=assert(api.list()[1]);assert(#mod.pages==2 and mod.pages[1].name=='Settings'and mod.pages[2].name=='Appearance')
assert(#mod.pages[1].controls==3 and #mod.pages[2].controls==7)
local delay,random
for _,c in ipairs(mod.pages[1].controls)do
 if c.type=='slider'then delay=c elseif c.label=='Advanced / Randomize input delay'then random=c end
end
assert(delay and random and not delay.disabled)
assert(mod.handle.set(random.id,true));assert(delay.disabled,'random mode disables and dims fixed slider')
assert(mod.handle.set(random.id,false));assert(not delay.disabled,'fixed slider restores when random mode is off')
local by_label={};for _,c in ipairs(mod.pages[2].controls)do by_label[c.label]=c end
assert(not by_label['Full-color stratagem icons'],'retired live registrations stay hidden')
assert(by_label.Mode.column==1 and by_label['Dock gap'].column==2 and by_label['Show cooldown timers'].column==2)
assert(mod.pages[2].controls[1].type=='section'and mod.pages[2].controls[2].label=='Mode','mode leads selection group')
local key=by_label['Show cooldown timers'].id;assert(mod.handle.edit(key,false));assert(mod.handle.confirm('appearance'))
assert(host.get('native_stratagem_radial.cooldown_timers')==false,'original saved ID and callbacks retained')
assert(mod.handle.set(by_label.Mode.id,2));assert(host.get('native_stratagem_radial.selection_mode_ordered')==2,'moved mode retains native save ID')
assert(not by_label['Wedge Wheel layout'].disabled,'List Select retains editable Wedge Wheel settings')
assert(mod.handle.set(by_label.Mode.id,3));assert(not by_label['Wedge Wheel layout'].disabled,'native wheel retains editable Wedge Wheel settings')
assert(mod.handle.set(by_label.Mode.id,1));assert(not by_label['Wedge Wheel layout'].disabled,'Wedge Wheel restores its layout control')
assert(host.get('native_stratagem_radial.experimental_layout')==2,'disabling retains selected layout')
assert(mod.handle.edit(by_label.Mode.id,2));assert(not by_label['Wedge Wheel layout'].disabled,'draft List Select retains editable layout')
assert(mod.handle.edit(by_label.Mode.id,1));assert(not by_label['Wedge Wheel layout'].disabled,'draft Wedge Wheel enables layout immediately')
assert(mod.handle.edit(by_label.Mode.id,3));assert(not by_label['Wedge Wheel layout'].disabled)
assert(mod.handle.discard('appearance'));assert(not by_label['Wedge Wheel layout'].disabled,'discard restores dependency state')
assert(mod.handle.edit(by_label.Mode.id,2));assert(mod.handle.confirm('appearance'));assert(not by_label['Wedge Wheel layout'].disabled)
assert(mod.handle.edit(by_label.Mode.id,1));assert(not by_label['Wedge Wheel layout'].disabled)
assert(mod.handle.confirm('appearance'));assert(not by_label['Wedge Wheel layout'].disabled,'confirm preserves enabled state')
assert(mod.handle.edit(random.id,true));assert(delay.disabled,'draft randomization disables fixed delay')
assert(mod.handle.discard('settings'));assert(not delay.disabled,'discard restores fixed delay')
local same=api.revision;assert(not mod.handle.set_disabled(delay.id,false));assert(api.revision==same,'unchanged dependency state stays idle')
local rev=api.revision;for i=1,10000 do bridge.poll(host)end;assert(api.revision==rev)
bridge.release();assert(#api.list()==0)
print('DBF Appearance page: split, native save IDs, confirmation, cleanup and 10000 idle imports passed')
