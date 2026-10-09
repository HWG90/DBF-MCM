-- Standalone safety contracts; positive owner recovery uses hud_plus_verify --runtime.
local Runtime=dofile('src/integrations/hud_plus_runtime.lua')
local calls=0
for _,data in ipairs({'','return os.execute("anything")','DBF-HUD-PLUS-METADATA\t1\t0.2.2','\0','DBF-HUD-PLUS-METADATA\t1\t0.2.3'})do
 assert(not pcall(Runtime.parse_metadata,data),'Malformed/unsupported metadata accepted')
end
local metadata,why=Runtime.read_metadata('tests/hud_plus_metadata_missing_fixture.tsv');assert(not metadata and why)
local loop;loop=function(...)calls=calls+1;return loop(...)end
assert(Runtime.find(loop,{})==nil and calls==0,'Closure traversal executed a loop')
local inner=loop
for _=1,40 do local previous_update=inner;inner=function(...)calls=calls+1;return previous_update(...)end end
assert(Runtime.find(inner,{})==nil and calls==0,'Traversal ignored bounds or executed wrappers')
local function tree(depth)
 if depth==0 then return function()calls=calls+1 end end
 local inner,original=tree(depth-1),tree(depth-1)
 return function(...)inner(...);return original(...)end
end
local _,reason,_,_,diagnostic=Runtime.find(tree(9),{})
assert(diagnostic.nodes==256 and diagnostic.node_limit==256 and diagnostic.budget_exhausted and reason:find('nodes=256',1,true) and calls==0,'Lua node budget or diagnostics failed')
local _,_,_,_,c_diagnostic=Runtime.find(math.floor,{})
assert(c_diagnostic.nodes==0 and calls==0,'C builtin was treated as a Lua closure')
local hook={driver=setmetatable({},{__index=function()calls=calls+1;error('Unknown owner metamethod executed')end})}
local function untrusted_hook(...)calls=calls+1;return hook.driver.frame(...)end
assert(Runtime.find(untrusted_hook,{})==nil and calls==0,'Unknown owner metatable was executed')
local globals={update=loop};local provider=Runtime.new('',function()error('No success log expected')end,{globals=globals,metadata={}})
assert(not provider.poll());assert(globals.update==loop and globals.HD2HUDPlusMCMBridge==nil and calls==0)
local foreign={api=1,version='0.2.2',independent=true};globals.HD2HUDPlusMCMBridge=foreign
assert(provider.poll()==foreign);provider.release();assert(globals.HD2HUDPlusMCMBridge==foreign and globals.update==loop)
local direct=Runtime.new('tests/no_hud_metadata',nil,{globals=globals})
assert(direct.poll()==foreign and direct.diagnostic()=='HUD+ owner-provided bridge available','Owner bridge incorrectly required metadata')
direct.release();assert(globals.HD2HUDPlusMCMBridge==foreign,'Direct bridge was removed on MCM retirement')
local cached={installed=true,mcm_bridge=foreign};local cache={['mods/hd2_hud/hd2_hud_plus']=cached};local private_globals={update=loop}
local module_provider=Runtime.new('tests/no_hud_metadata',nil,{globals=private_globals,loaded=cache})
assert(module_provider.poll()==foreign,'HUD+ cached export in a private namespace was ignored')
assert(private_globals.HD2HUDPlusMCMBridge==nil,'MCM republished a foreign owner bridge')
module_provider.release();assert(cached.mcm_bridge==foreign,'MCM modified the cached HUD+ owner')
print('PASS runtime HUD+ metadata refusal, bounded nonexecuting closure inspection, unknown-metatable safety and foreign bridge ownership')
