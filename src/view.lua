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
        local old_ids=ids;ids={}
        for index,c in ipairs(commands)do
            local z=(c.layer or 100)+index*.01
            local signature=table.concat({c.type,c.text or '',c.x,c.y,c.w or 0,c.h or 0,c.size or 0,c.a,c.c[1],c.c[2],c.c[3],z,c.font_resource or '',c.font_material or ''},'|')
            local old=old_ids[index]
            if old and old.signature==signature then
                ids[#ids+1]=old
            else
            if old then pcall(G['destroy_'..old.type],gui,old.id) end
            local color=sr.Color(math.floor(c.a*255+.5),c.c[1],c.c[2],c.c[3]);local value
            if c.type=='rect' then value=G.rect(gui,sr.Vector3(c.x,c.y,z),sr.Vector2(c.w,c.h),color)
            else
                local font,material='core/performance_hud/debug','core/performance_hud/debug'
                if c.font_resource then font,material=c.font_resource,c.font_material end
                value=G.text(gui,c.text,font,c.size,material,sr.Vector3(c.x,c.y,z),color)
            end
            if value then ids[#ids+1]={type=c.type,id=value,signature=signature}else ids[#ids+1]={type=c.type,id=nil,signature=nil}end
            end
        end
        for index=#commands+1,#old_ids do local old=old_ids[index];pcall(G['destroy_'..old.type],gui,old.id)end
    end
    return self
end
return M
