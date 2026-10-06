local Core=dofile('src/core.lua');local defaults,owned=0,0
local api=Core.new({load=function()return {}end,save=function()defaults=defaults+1;return true end})
local values={key=119};local storage={load=function(id)assert(id=='own');return values end,save=function(id,data)assert(id=='own');owned=owned+1;values=data;return true end}
local h=api.register({id='own',name='Own storage',storage=storage,pages={{id='p',name='P',controls={{id='key',type='keybind',label='Key',default=121}}}}})
assert(h.get('key')==119);assert(h.set('key',120)and owned==1 and defaults==0)
h.unregister();local fresh=Core.new();local again=fresh.register({id='own',name='Own',storage=storage,pages={{id='p',name='P',controls={{id='key',type='keybind',label='Key',default=121}}}}});assert(again.get('key')==120)
assert(api.storage_per_mod and api.presentation_links and api.text_swatches)
print('PASS: per-mod storage is authoritative, survives provider changes, and never writes unrelated framework settings')
