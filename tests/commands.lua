-- Actual registry handles, persistence and grouping; no game, native or evaluator.
local Bus=dofile('src/commands.lua');local Core=dofile('src/core.lua');local Grouping=dofile('src/grouping.lua')
local passed=0
local function test(name,fn)local ok,why=pcall(fn);assert(ok,name..': '..tostring(why));passed=passed+1;print('PASS '..name)end
local function has(items,value)for _,item in ipairs(items)do if(type(item)=='table'and item.text or item)==value then return true end end;return false end
local function fixture()
 local writes,callbacks,actions=0,0,0;local fail=false;local saved={}
 local api=Core.new({load=function()return {}end,save=function(owner,values)
  if fail then return false,'disk refused'end;writes=writes+1;saved[owner]=values;return true
 end},nil,Grouping)
 local handle=api.register({id='demo',name='Demo',pages={{id='main',name='Main',require_confirmation=true,controls={
  {id='enabled',type='toggle',label='Enabled',default=false,on_change=function()callbacks=callbacks+1 end},
  {id='opacity',type='slider',label='Opacity',min=0,max=1,step=.01,default=.5},
  {id='name',type='input',label='Name',default='Initial'},
  {id='color',type='color',label='Color',default='#FFFFFF'},
  {id='choice',type='choice',label='Choice',choices={'One','Two'},default=1},
  {id='key',type='keybind',label='Key',default=65},
  {id='disabled',type='toggle',label='Disabled',default=false,disabled=true},
  {id='action',type='button',label='Action',on_activate=function()actions=actions+1;return 'Owner ran'end},
  {id='blocked',type='button',label='Blocked',disabled=true,on_activate=function()error('Must not run')end},
  {type='text',label='Description'},
 }}}})
 return {api=api,handle=handle,bus=Bus.new(api),counts=function()return writes,callbacks,actions end,fail=function(value)fail=value end,saved=saved}
end
test('typed assignments use authoritative setters and preserve validation, saves and callbacks',function()
 local f=fixture();assert(f.bus.api==1)
 assert(f.bus.execute('mods.demo.enabled = true'));assert(f.handle.get('enabled')and f.handle.preview('enabled'))
 local w,c=f.counts();assert(w==1 and c==1,'Command bypassed owner commit or callback')
 assert(f.bus.execute('mods.demo.opacity = 8.26e-1')and math.abs(f.handle.get('opacity')-.83)<.000001,'Owner rounding was bypassed')
 assert(f.bus.execute('mods.demo.name = "Mission ready"')and f.handle.get('name')=='Mission ready')
 assert(f.bus.execute('mods.demo.color = "ffe800"')and f.handle.get('color')=='#FFE800')
 assert(f.bus.execute('mods.demo.choice = 2')and f.handle.get('choice')==2)
 assert(f.bus.execute('mods.demo.key = 120')and f.handle.get('key')==120)
 for _,command in ipairs({'mods.demo.enabled = "true"','mods.demo.opacity = 1.01','mods.demo.choice = 3','mods.demo.key = 256','mods.demo.disabled = true'})do assert(not f.bus.execute(command),'Invalid/disabled value accepted: '..command)end
 f.fail(true);local ok,why=f.bus.execute('mods.demo.enabled = false')
 assert(not ok and why=='disk refused'and f.handle.get('enabled'),'Failed write changed owner state')
 assert(f.saved.demo.enabled,'Wrong storage owner/value')
end)
test('list and completion reflect metadata without reading values or running setters/actions',function()
 local f=fixture();local get,set,activate=f.handle.get,f.handle.set,f.handle.activate
 f.handle.get=function()error('Completion read a value')end;f.handle.set=function()error('Completion saved a value')end;f.handle.activate=function()error('Completion ran an action')end
 assert(has(f.bus.list(),'mods.demo.enabled')and not has(f.bus.list(),'mods.demo.Description'))
 assert(has(f.bus.suggest('get mods.demo.en'),'get mods.demo.enabled'))
 assert(has(f.bus.suggest('mods.demo.enabled = t'),'mods.demo.enabled = true'))
 assert(has(f.bus.suggest('  mods.demo.enabled = f'),'  mods.demo.enabled = false'))
 assert(has(f.bus.suggest('run mods.demo.'),'run mods.demo.action')and not has(f.bus.suggest('run mods.demo.'),'run mods.demo.enabled')and not has(f.bus.suggest('run mods.demo.'),'run mods.demo.blocked'))
 assert(#f.bus.suggest('os.execute(')==0 and #f.bus.suggest(string.rep('a',1025))==0)
 assert(f.bus.execute('help mods.demo.')and f.bus.execute('list'))
 f.handle.get,f.handle.set,f.handle.activate=get,set,activate
 local ok,reported=f.bus.execute('get mods.demo.enabled');assert(ok and reported=='mods.demo.enabled = false')
end)
test('button actions require explicit run and keep owner refusal/error handling',function()
 local f=fixture()
 for _,command in ipairs({'mods.demo.action','get mods.demo.action','mods.demo.action = true','run mods.demo.enabled','run mods.demo.blocked','run mods.demo.action extra'})do assert(not f.bus.execute(command),'Implicit/invalid action ran')end
 local w,c,a=f.counts();assert(w==0 and c==0 and a==0)
 local ok,why=f.bus.execute('run mods.demo.action');assert(ok and why=='Owner ran');w,c,a=f.counts();assert(a==1 and w==0)
 f.handle.activate=function()return false,'Owner refused'end
 ok,why=f.bus.execute('run mods.demo.action');assert(not ok and why=='Owner refused')
end)
test('mounted and linked paths call the owning handle and disappear on retirement',function()
 local f=fixture();local child=f.api.register({id='child',name='Child',parent_name='Demo',pages={{id='main',name='Child',controls={{id='flag',type='toggle',label='Child flag',default=false}}}}})
 assert(has(f.bus.list(),'mods.demo.child__flag')and not has(f.bus.list(),'mods.child.flag'))
 assert(f.bus.execute('mods.demo.child__flag = true')and child.get('flag')and f.saved.child.flag,'Mounted path wrote a parent copy')
 f.api.register({id='links',name='Links',pages={{id='main',name='Links',controls={{id='alias',type='toggle',label='Alias',default=false,source_mod_id='child',source_control_id='flag'}}}}})
 assert(f.bus.execute('mods.links.alias = false')and not child.get('flag')and not f.saved.child.flag,'Linked alias bypassed owner')
 child.unregister();assert(not has(f.bus.list(),'mods.demo.child__flag')and not has(f.bus.suggest('mods.links.'),'mods.links.alias'))
 assert(not f.bus.execute('mods.demo.child__flag = true')and not f.bus.execute('mods.links.alias = true'),'Retired route survived lookup')
 f.handle.unregister();assert(not has(f.bus.list(),'mods.demo.enabled')and not f.bus.execute('get mods.demo.enabled'))
 f.api.register({id='demo',name='Replacement',pages={{id='main',name='Main',controls={{id='enabled',type='toggle',label='Enabled',default=true}}}}})
 local ok,value=f.bus.execute('get mods.demo.enabled');assert(ok and value=='mods.demo.enabled = true','Replacement retained old handle/value')
end)
test('JSON scalar parser rejects Lua and malformed syntax while decoding escaped Unicode safely',function()
 local value='';local writes=0
 local api={list=function()return{{id='strings',pages={{controls={{id='value',type='input'}}}},handle={get=function()return value end,set=function(_,next_value)value=next_value;writes=writes+1;return true end}}}end}
 local bus=Bus.new(api)
 assert(bus.execute('mods.strings.value = "quote: \\" slash: \\\\ line: \\n"'))
 assert(value=='quote: " slash: \\ line: \n','JSON escapes changed')
 assert(bus.execute('mods.strings.value = "\\u0041\\u00e9\\uD83D\\uDE80"'))
 assert(value=='A\195\169\240\159\154\128','Unicode or surrogate decoding changed')
 local before=writes
 for _,literal in ipairs({'null','{}','[]','function() end','os.execute("x")','0x10','+1','01','1.','1e','1e999','NaN','Infinity','"unterminated','"bad\\q"','"\\uD800"','"\\uDC00"','"\\uD800\\u0041"','"raw\nline"','"escaped\\"'})do
  assert(not bus.execute('mods.strings.value = '..literal),'Malformed/Lua literal accepted: '..literal)
 end
 assert(writes==before,'Rejected input invoked setter')
 assert(not bus.execute(string.rep('x',1025))and not bus.execute('loadstring("x")()'))
end)
test('verbose helpers support false readback and completion has no helper side effects',function()
 local verbose=false;local reads,writes=0,0
 local api={list=function()return{}end}
 local bus=Bus.new(api,{get_verbose=function()reads=reads+1;return verbose end,set_verbose=function(value)writes=writes+1;verbose=value;return value end})
 assert(has(bus.list(),'mcm.verbose_registration')and has(bus.suggest('mcm.verbose_registration = f'),'mcm.verbose_registration = false')and reads==0 and writes==0)
 assert(bus.execute('mcm.verbose_registration = true')and verbose)
 assert(bus.execute('mcm.verbose_registration = false')and not verbose and writes==2,'False helper return was treated as failure')
 local ok,why=bus.execute('get mcm.verbose_registration');assert(ok and why=='mcm.verbose_registration = false')
 assert(not bus.execute('mcm.verbose_registration = 1')and writes==2)
 local refused=Bus.new(api,{get_verbose=function()return false end,set_verbose=function()return false,'No permission'end})
 ok,why=refused.execute('mcm.verbose_registration = true');assert(not ok and why=='No permission')
end)
test('standalone console completion does not execute and Enter commits through the same bus',function()
 local f=fixture();local Console=dofile('src/console.lua');local model=Console.new();model.commands=f.bus
 local surface=Console.surface(model);local keys={};local input={down=function(key)return keys[key]==true end,mouse=function()return 0,0 end}
 surface.filter(input,true);surface.focus();surface.filter(input,true)
 model.window.command_text='mods.demo.en'
 surface.compose(1920,1080,{x=0,y=600,w=1100,h=400},true)
 keys[9]=true;surface.filter(input,true);keys[9]=false;surface.filter(input,true)
 assert(model.window.command_text=='mods.demo.enabled'and not f.handle.get('enabled'),'Tab completion ran a setter')
 model.window.command_text='mods.demo.enabled = t'
 surface.compose(1920,1080,{x=0,y=600,w=1100,h=400},true)
 keys[9]=true;surface.filter(input,true);keys[9]=false;surface.filter(input,true)
 assert(model.window.command_text=='mods.demo.enabled = true'and not f.handle.get('enabled'),'Value completion ran a setter')
 keys[13]=true;local filtered=surface.filter(input,true);keys[13]=false;surface.filter(input,true)
 assert(not filtered.down(13)and f.handle.get('enabled'),'Console Enter leaked or did not commit')
 local writes,callbacks=f.counts();assert(writes==1 and callbacks==1,'Console bus duplicated owner writes/callbacks')
 assert(model.window.command_history[#model.window.command_history]=='mods.demo.enabled = true')
 surface.release()
end)
print('PASS '..passed..' standalone typed-command contracts: owners, metadata completion, explicit actions, retirement, safe JSON and verbose helpers')
