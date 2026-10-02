-- Isolated native GUI layers; unchanged frames retain their primitives.
local M={}
function M.new(sr)
    local world;local layers={};local previous;local G=sr.Gui;local self={}
    local function live()for _,w in pairs(sr.Application.worlds() or {})do if w==world then return true end end;return false end
    function self.clear()
        if live()then for _,layer in pairs(layers)do
            for _,item in ipairs(layer.ids)do G['destroy_'..item.type](layer.gui,item.id)end
            layer.ids={}
        end end
        previous=nil
    end
    function self.release()
        if live()then self.clear();for _,layer in pairs(layers)do sr.World.destroy_gui(world,layer.gui)end end
        layers={};world=nil;previous=nil
    end
    local function same(commands)
        if not previous or #previous~=#commands then return false end
        for i,c in ipairs(commands)do local p=previous[i]
            for _,key in ipairs({'type','x','y','w','h','text','size','a','layer'})do if c[key]~=p[key]then return false end end
            for k=1,3 do if c.c[k]~=p.c[k]then return false end end
        end
        return true
    end
    function self.draw(commands)
        if #commands==0 then self.release();return end
        if world and not live()then layers={};world=nil;previous=nil end
        if not world then world=sr.Application.main_world();if not world then return end end
        if same(commands)then return end
        self.clear()
        local order={};local depths={};local used={}
        for index in ipairs(commands)do order[index]=index end
        table.sort(order,function(a,b)
            local x,y=commands[a].layer or 100,commands[b].layer or 100
            return x==y and a<b or x<y
        end)
        for rank,index in ipairs(order)do depths[index]=rank end
        for index,c in ipairs(commands)do
            local key=c.layer or 100;used[key]=true
            local layer=layers[key]
            if not layer then layer={gui=sr.World.create_screen_gui(world,'scale',1,1),ids={}};layers[key]=layer end
            local color=sr.Color(math.floor(c.a*255+.5),c.c[1],c.c[2],c.c[3]);local value
            if c.type=='rect' then value=G.rect(layer.gui,sr.Vector3(c.x,c.y,depths[index]),sr.Vector2(c.w,c.h),color)
            else value=G.text(layer.gui,c.text,'core/performance_hud/debug',c.size,'core/performance_hud/debug',sr.Vector3(c.x,c.y,depths[index]),color)end
            assert(value~=nil,'Native GUI failed to create '..c.type..' at command '..index)
            layer.ids[#layer.ids+1]={type=c.type,id=value}
        end
        for key,layer in pairs(layers)do if not used[key]then sr.World.destroy_gui(world,layer.gui);layers[key]=nil end end
        previous={}
        for i,c in ipairs(commands)do local p={};for k,v in pairs(c)do p[k]=v end;p.c={c.c[1],c.c[2],c.c[3]};previous[i]=p end
    end
    return self
end
return M
