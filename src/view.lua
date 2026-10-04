-- Uses stock Stingray GUI and stock font; no HUD asset dependency.
local M={}
function M.new(sr,preview_only,diagnostic_log)
    local preview_guis={}
    local gui,world;local ids={};local G=sr.Gui;local self={};local reported=false
    local preview_materials={}
    local preview_view=not preview_only and M.new(sr,true,diagnostic_log) or nil
    local popup_view=not preview_only and M.new(sr,true) or nil
    local function live()for _,w in pairs(sr.Application.worlds() or {})do if w==world then return true end end;return false end
    local metrics={}
    function self.measure(glyph,size)
        local key=glyph..'|'..size;if metrics[key]then return metrics[key]end
        local width=size*.62
        if gui and live() and type(G.text_extents)=='function' then
            local ok,value=pcall(function()
                local lo,hi=G.text_extents(gui,'M'..glyph,'core/performance_hud/debug',size)
                local base_lo,base_hi=G.text_extents(gui,'M','core/performance_hud/debug',size)
                return (hi.x-lo.x)-(base_hi.x-base_lo.x)
            end)
            if ok and type(value)=='number' and value>0 and value<1000 then width=math.max(width,value)end
            metrics[key]=width
        end
        return width
    end
    local function destroy_item(item)
        pcall(G['destroy_'..item.type],item.gui or gui,item.id);if item.extra_id then pcall(G.destroy_triangle,item.gui or gui,item.extra_id)end
    end
    function self.clear()
        if gui and live()then for _,item in ipairs(ids)do destroy_item(item)end end;ids={}
    end
    function self.release()if preview_view then preview_view.release()end;if popup_view then popup_view.release()end;reported=false;if gui and live()then self.clear();for _,g in pairs(preview_guis)do sr.World.destroy_gui(world,g)end;preview_guis={};sr.World.destroy_gui(world,gui)end;gui,world=nil,nil end
    function self.draw(commands)
        if preview_view then
            local menu,preview,popup={},{},{}
            for _,c in ipairs(commands)do
                local destination=c.hud_preview and preview or (c.popup and popup or menu)
                destination[#destination+1]=c
            end
            preview_view.draw(preview);popup_view.draw(popup);commands=menu
        end
        if #commands==0 then self.release();return end
        if gui and not live()then gui,world=nil,nil;ids={};preview_guis={}end
        if not gui then
            local main=sr.Application.main_world();world=main
            for _,w in pairs(sr.Application.worlds() or {})do if w~=main then world=w;break end end
            if not world then return end
            gui=sr.World.create_screen_gui(world,'scale',1,1)
        end
        local function command_gui(c)
            if not c.preview_role then return gui end
            preview_guis[c.preview_role]=preview_guis[c.preview_role] or sr.World.create_screen_gui(world,'scale',1,1)
            return preview_guis[c.preview_role]
        end
        local old_ids=ids;ids={};local report={};local seen={};local uniforms={}
        local report_now=diagnostic_log and not reported
        local signatures={}
        for index,c in ipairs(commands)do
            -- Sidebar command counts must not change unrelated content depth.
            local z=(c.layer or 100)+(c.type=='text' and 1 or 0)
            signatures[index]=table.concat({c.type,c.text or '',c.x,c.y,c.w or 0,c.h or 0,c.size or 0,c.a,c.c[1],c.c[2],c.c[3],z,c.font_resource or '',c.font_material or '',c.preview_material or '',c.preview_uv and table.concat(c.preview_uv,',') or '',c.preview_role or ''},'|')
        end
        -- Destroy all stale IDs before allocations: engines may reuse IDs immediately.
        for index,old in ipairs(old_ids)do
            if old.signature~=signatures[index] then
                destroy_item(old);old_ids[index]=false
            end
        end
        for index,c in ipairs(commands)do
            -- Sidebar command counts must not change unrelated content depth.
            local z=(c.layer or 100)+(c.type=='text' and 1 or 0)
            local signature=signatures[index]
            local target_gui=command_gui(c)
            local old=old_ids[index]
            -- Refresh uniforms for retained preview triangles on every draw.
            local uniform_key=(c.preview_role or '')..':'..(c.preview_material or '')
            if c.preview_material and not uniforms[uniform_key] and sr.Application.can_get('material',c.preview_material) then
                local handle=G.material(target_gui,c.preview_material)
                if handle then
                    sr.Material.set_scalar(handle,'scissor_mode',0)
                    sr.Material.set_scalar(handle,'threshold_fade',0)
                    if c.preview_mapping then
                        local r=c.preview_mapping
                        sr.Material.set_vector4(handle,'scissor_rect',sr.Vector4(r[1],r[2],r[3],0))
                        sr.Material.set_vector4(handle,'atlas_scissor',sr.Vector4(r[4],r[5],r[6],0))
                        sr.Material.set_vector4(handle,'clip_box',sr.Vector4(r[7],r[8],r[9],0))
                    end
                    uniforms[uniform_key]=true
                end
            end
            if report_now and c.type=='text' then report[#report+1]=string.format('%d z=%.2f label=%q',index,z,c.text or '')end
            if old and old.signature==signature then
                ids[#ids+1]=old
            else
            local color=sr.Color(math.floor(c.a*255+.5),c.c[1],c.c[2],c.c[3]);local value;local primitive_type=c.type;local extra_id
            if c.type=='rect' and c.preview_material and type(G.triangle)=='function' and sr.Application.can_get('material',c.preview_material) then
                local handle=assert(G.material(target_gui,c.preview_material),'Preview material unavailable')
                sr.Material.set_scalar(handle,'scissor_mode',0);sr.Material.set_scalar(handle,'threshold_fade',0)
                local a=sr.Vector3(c.x,0,c.y);local b=sr.Vector3(c.x+c.w,0,c.y)
                local d=sr.Vector3(c.x+c.w,0,c.y+c.h);local e=sr.Vector3(c.x,0,c.y+c.h)
                local uv=c.preview_uv
                local ua=uv and sr.Vector2(uv[1],uv[4]) or nil;local ub=uv and sr.Vector2(uv[3],uv[4]) or nil
                local ud=uv and sr.Vector2(uv[3],uv[2]) or nil;local ue=uv and sr.Vector2(uv[1],uv[2]) or nil
                value=G.triangle(target_gui,a,b,d,z,color,c.preview_material,ua,ub,ud)
                extra_id=G.triangle(target_gui,a,d,e,z,color,c.preview_material,ua,ud,ue);primitive_type='triangle'
                if diagnostic_log and not preview_materials[c.preview_material] then preview_materials[c.preview_material]=true;diagnostic_log('MCM_PREVIEW_SHADER material='..c.preview_material..' triangles='..tostring(value)..','..tostring(extra_id)..' bounds='..c.x..','..c.y..','..c.w..','..c.h)end
            elseif c.type=='rect' then value=G.rect(gui,sr.Vector3(c.x,c.y,z),sr.Vector2(c.w,c.h),color)
            else
                local font,material='core/performance_hud/debug','core/performance_hud/debug'
                if c.font_resource then font,material=c.font_resource,c.font_material end
                value=G.text(gui,c.text,font,c.size,material,sr.Vector3(c.x,c.y,z),color)
            end
            if report_now and c.type=='text' then report[#report]=report[#report]..' allocation='..tostring(value)end
            if value then ids[#ids+1]={type=primitive_type,id=value,extra_id=extra_id,signature=signature,gui=target_gui}else ids[#ids+1]={type=c.type,id=nil,signature=nil}end
            end
        end
        if report_now then
            local duplicate=0;for _,item in ipairs(ids)do local key=item.type..':'..tostring(item.id);if seen[key]then duplicate=duplicate+1 end;seen[key]=true end
            diagnostic_log('MCM TEXT DIAGNOSTIC primitives='..#commands..' duplicate_handles='..duplicate)
            for _,line in ipairs(report)do diagnostic_log('MCM TEXT '..line)end
            reported=true
        end
    end
    return self
end
return M
