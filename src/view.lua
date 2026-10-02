-- Uses stock Stingray GUI and stock font; no HUD asset dependency.
local M={}
function M.new(sr)
    local gui,world;local ids={};local G=sr.Gui;local self={}
    local function live()for _,w in pairs(sr.Application.worlds() or {})do if w==world then return true end end;return false end
    function self.clear()
        if gui and live()then for _,item in ipairs(ids)do pcall(G['destroy_'..item.type],gui,item.id)end end;ids={}
    end
    function self.release()if gui and live()then self.clear();sr.World.destroy_gui(world,gui)end;gui,world=nil,nil end
    function self.draw(commands)
        if #commands==0 then self.release();return end
        if gui and not live()then gui,world=nil,nil;ids={}end
        if not gui then
            local main=sr.Application.main_world();world=main
            for _,w in pairs(sr.Application.worlds() or {})do if w~=main then world=w;break end end
            if not world then return end
            gui=sr.World.create_screen_gui(world,'scale',1,1)
        end
        self.clear()
        local order={};local depths={}
        for index in ipairs(commands)do order[index]=index end
        table.sort(order,function(a,b)
            local x,y=commands[a].layer or 100,commands[b].layer or 100
            return x==y and a<b or x<y
        end)
        for rank,index in ipairs(order)do depths[index]=rank end
        for index,c in ipairs(commands)do
            -- Native GUI depth may quantize fractional steps. Keep each primitive
            -- on a distinct integer plane, with ranks local to its popup layer.
            local z=depths[index]
            local color=sr.Color(math.floor(c.a*255+.5),c.c[1],c.c[2],c.c[3]);local value
            if c.type=='rect' then value=G.rect(gui,sr.Vector3(c.x,c.y,z),sr.Vector2(c.w,c.h),color)
            else value=G.text(gui,c.text,'core/performance_hud/debug',c.size,'core/performance_hud/debug',sr.Vector3(c.x,c.y,z),color)end
            if value then ids[#ids+1]={type=c.type,id=value}end
        end
    end
    return self
end
return M
