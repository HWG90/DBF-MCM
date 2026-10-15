local module=dofile('src/capture.lua');local flags={focus=true,cursor=false,clip=false}
local silent=false;local gate=0;local sticky=false
local window={}
for _,pair in ipairs({{'mouse_focus','focus'},{'show_cursor','cursor'},{'clip_cursor','clip'}})do
 local key,name=pair[1],pair[2];window[key]=function()return flags[name]end
 window['set_'..key]=function(v)if not silent then flags[name]=v end end
end
local native={mcm_install=function()return 1 end,mcm_capture=function()gate=1;return 1 end,mcm_captured=function()return gate end,mcm_release=function()if not sticky then gate=0 end end}
local c=module.new(native,window,function()end)
gate=1;assert(c.release() and gate==1,'inactive cleanup released another frontend')
local foreign_ok,foreign_why=c.sync(true,true,1);assert(not foreign_ok and foreign_why:find('another frontend',1,true) and gate==1)
gate=0
flags.focus=false;local ok,why=c.sync(true,true,1);assert(not ok and gate==0 and why:find('already disabled',1,true))
flags.focus=true;assert(c.sync(true,true,1));silent=true
ok,why=c.release();assert(not ok and c.status().pending_restore and why:find('readback',1,true))
silent=false;assert(c.sync(false,true,1) and flags.focus and not flags.cursor and not flags.clip)
assert(c.sync(true,true,1));sticky=true;ok,why=c.release();assert(not ok and c.status().pending_restore and gate==1)
sticky=false;assert(c.sync(false,true,1) and flags.focus and gate==0)
print('PASS stale baseline refusal, silent setter verification, retained restoration retry and native gate readback')

-- Separate frontend DLLs have independent native gates. The engine Window
-- baseline must therefore reject an overlapping external camera lease too.
local Camera=dofile('src/camera_input.lua')
for _,baseline in ipairs({{cursor=false,clip=false},{cursor=false,clip=true},{cursor=true,clip=true}})do
 local state={focus=true,cursor=baseline.cursor,clip=baseline.clip};local writes=0
 local w={}
 for _,field in ipairs({{'mouse_focus','focus'},{'show_cursor','cursor'},{'clip_cursor','clip'}})do
  local getter,key=field[1],field[2];w[getter]=function()return state[key]end
  w['set_'..getter]=function(v)writes=writes+1;state[key]=v;return true end
 end
 local gates,changes={0,0},{0,0}
 local function helper(index)
  return{mcm_install=function()changes[index]=changes[index]+1;return 1 end,
   mcm_capture=function(mode)changes[index]=changes[index]+1;gates[index]=mode;return 1 end,
   mcm_captured=function()return gates[index]end,
   mcm_release=function()changes[index]=changes[index]+1;gates[index]=0 end}
 end
 local other_native,our_native=helper(1),helper(2)
 local other=module.new(other_native,w,function()end);local own=module.new(our_native,w,function()end)
 local input={poll=function()end,focused=function()return true end,window=function()return 1 end,
  lock_aim=function()w.set_mouse_focus(false);return true end,
  menu_cursor=function(menu)w.set_mouse_focus(false);w.set_show_cursor(menu);w.set_clip_cursor(true);return true end,
  down=function()return false end,wheel=function()return 0 end}
 local camera=Camera.new(our_native,own,input,function()return true end)
 assert(other.sync(true,true,1)and gates[1]==1 and not state.focus)
 local prior_writes,prior_native=writes,changes[1]
 for attempt=1,3 do
  local token,reason=camera.acquire({})
  assert(token==nil and reason:find('already disabled',1,true),'external camera acquired a disabled gameplay baseline')
  assert(own.status().owner==nil and not own.status().active,'refused external lease retained a token')
  assert(writes==prior_writes and changes[2]==0,'external baseline refusal changed Window or native state')
  assert(gates[1]==1 and changes[1]==prior_native,'external refusal touched the other frontend native helper')
 end
 assert(other.release()and state.focus)
 local token=assert(camera.acquire({}));assert(own.owns(token)and gates[2]==3 and not state.focus)
 assert(camera.release()and gates[1]==0 and gates[2]==0 and not own.status().owner)
 assert(state.focus and state.cursor==baseline.cursor and state.clip==baseline.clip,'external release changed the exact original gameplay cursor flags')
end
print('PASS two-helper external camera baseline refusal before writes/tokens, foreign lease protection, recovery and exact gameplay restoration')
