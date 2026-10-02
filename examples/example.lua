-- Run from your own mod's update until DBFMCM is available, then register once.
-- Keep the returned handle and unregister it when your mod is disabled.
local handle,owner
return {
    name="DBF-MCM Minimal Example",version="1.0.0",description="Example settings only",
    on_enable=function(ctx)ctx.on_cleanup(function()if handle then handle.unregister();handle=nil end;owner=nil end)end,
    on_update=function(ctx,dt)
        local mcm=rawget(_G,'DBFMCM')
        if mcm and (not handle or owner~=mcm)then
            if handle then handle.unregister()end
            handle=mcm.register({id='example_mod',name='Example Mod',pages={
                {id='general',name='General',controls={
                    {id='enabled',type='toggle',label='Enabled',default=true,
                     description='Enable the example feature.',on_change=function(value)ctx.log('Enabled: '..tostring(value))end},
                    {id='intensity',type='slider',label='Intensity',default=50,min=0,max=100,step=1,
                     description='Adjust the effect strength.'}}}}})
            owner=mcm
            -- Read saved values immediately; registration does not fire change callbacks.
            ctx.log('Restored intensity: '..handle.get('intensity'))
        end
    end,
    on_disable=function()if handle then handle.unregister();handle=nil end end,
}
