local Core=dofile('src/core.lua')
local api=Core.new(nil,function()end)
local function spec()return{id='demo',name='Demo',pages={{id='main',name='Main',controls={{id='value',type='toggle',label='Value',default=true}}}}}end
local old=api.register(spec());local oldmod=api.mods.demo;local calls=0
local replacement=assert(api.takeover(spec(),{source='lll',priority=100,release_legacy=function(prior)assert(prior==oldmod);calls=calls+1;return true end,release=function()return true end}))
assert(calls==1 and api.mods.demo.handle==replacement)
old.unregister();assert(api.mods.demo.handle==replacement)
local denied=api.takeover(spec(),{source='bundle',priority=0});assert(not denied and api.mods.demo.handle==replacement)
local bad=spec();bad.pages=nil;assert(not api.takeover(bad,{source='lll',priority=101}));assert(api.mods.demo.handle==replacement)
local blocked=Core.new(nil,function()end);local h=blocked.register(spec())
assert(not blocked.takeover(spec(),{source='lll',priority=100,release_legacy=function()return false,'pending' end}));assert(blocked.mods.demo.handle==h)
print('Menu takeover: validated handoff, priority, stale unregister, invalid replacement and pending cleanup passed')
