-- Standalone MDL API 2 consumer: safe example settings, no gameplay writes.
local owner,handle
local function release()if handle then handle.unregister()end;handle,owner=nil,nil end
return {
 name='DBF-MCM Advanced Example',version='1.0.0',description='Categories, colors, long choices and confirmation',
 on_enable=function(ctx)ctx.on_cleanup(release)end,
 on_disable=release,
 on_update=function(ctx)
  local api=rawget(_G,'DBFMCM');if not api or api.api~=1 or api==owner then return end
  release();local choices={};for i=1,100 do choices[i]='Preset '..i end
  handle=api.register({id='dbfmcm_advanced_example',name='MCM Advanced Example',
   categories={{id='hud',name='HUD'},{id='advanced',name='Advanced',parent='hud'}},pages={
    {id='colors',name='Colors',category='hud',controls={
     {id='accent',type='color',label='Accent color',default='#F4CA35',on_change=function(hex)ctx.log('Accent: '..hex)end}}},
    {id='location',name='Location',category='hud',controls={
     {id='x',type='slider',label='Horizontal offset',min=-100,max=100,step=.5,default=0},
     {id='preset',type='choice',label='Long preset list',choices=choices,default=1}}},
    {id='general',name='General',category='hud',controls={
     {id='enabled',type='toggle',label='Enabled',default=true},
     {id='hotkey',type='keybind',label='Example key code',default=0}}},
    {id='confirmed',name='Confirmed settings',category='advanced',require_confirmation=true,controls={
     {id='deliberate',type='toggle',label='Deferred setting',default=false,on_change=function(v)ctx.log('Confirmed: '..tostring(v))end},
     {id='action',type='button',label='Deferred log action',on_activate=function()ctx.log('Example action confirmed')end}}}
   }})
  owner=api;ctx.log('Restored accent: '..handle.get('accent'))
 end
}
