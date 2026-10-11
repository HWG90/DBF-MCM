local core=assert(loadfile('src/core.lua'))()
local compat=assert(loadfile('src/compat.lua'))()
local legacy=assert(loadfile('src/legacy.lua'))()
local host=compat.new(nil)
assert(host.register_option('camera.distance',{mod='Camera',type='slider',label='Distance',min=0,max=3,step=.05,default=0}))
local calls=0
host.on_change('camera.distance',function()calls=calls+1 end)
local api=core.new(nil,function()end)
legacy.new(api,function()end,core).poll(host)
local mod=api.list()[1];local handle=mod.handle;local key=mod.pages[1].controls[1].id
-- The camera writes its selected profile back through the original API.
assert(host.set('camera.distance',1.75))
assert(handle.get(key)==1.75)
assert(handle.edit(key,0))
assert(handle.preview(key)==0)
assert(handle.confirm('settings'))
assert(host.get('camera.distance')==0,'Apply discarded an edit matching the stale registration default')
assert(calls==1,'Apply did not notify the camera exactly once')
-- Switching profiles again must not leave the previous committed value cached.
assert(host.set('camera.distance',2))
assert(handle.edit(key,0))
assert(handle.confirm('settings'))
assert(host.get('camera.distance')==0 and calls==2)
print('Legacy profile writeback and repeated Apply regression passed')
