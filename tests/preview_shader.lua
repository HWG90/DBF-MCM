MCM={};MCM.view=assert(loadfile('src/view.lua'))()
local sr={Gui={},World={},Application={},Material={}};local world={};local next_gui=0;local handles={};local updates=0;local allocations=0;local destroyed=0
sr.Application.worlds=function()return {world}end;sr.Application.main_world=function()return world end;sr.Application.can_get=function()return true end
sr.World.create_screen_gui=function()next_gui=next_gui+1;return {n=next_gui}end
sr.World.destroy_gui=function()destroyed=destroyed+1 end
sr.Gui.material=function(g,n)handles[g.n]=handles[g.n] or {};handles[g.n][n]=handles[g.n][n] or {};return handles[g.n][n]end
sr.Gui.triangle=function()allocations=allocations+1;return allocations end;sr.Gui.destroy_triangle=function()end
sr.Material.set_scalar=function(h,k,v)h[k]=v end;sr.Material.set_vector4=function(h,k,v)h[k]=v;updates=updates+1 end
sr.Vector3=function(...)return {...}end;sr.Vector2=sr.Vector3;sr.Vector4=sr.Vector3;sr.Color=sr.Vector3
local view=MCM.view.new(sr,true);local commands={}
for i,role in ipairs({'main_panel','main_effect','child_panel','child_effect'})do commands[i]={type='rect',x=i*20,y=10,w=15,h=10,c={48,48,48},a=.8,preview_role=role,preview_material='mods/dbf_hud/materials/mapped_warning_hatch',preview_mapping={i,0,0,0,i,0,0,0,1}}end
view.draw(commands);assert(next_gui==5 and allocations==8 and updates==12)
for i,c in ipairs(commands)do c.preview_mapping[1]=i*2 end
view.draw(commands);assert(allocations==8 and updates==24)
for _,materials in pairs(handles)do local h=materials['mods/dbf_hud/materials/mapped_warning_hatch'];if h then assert(h.clip_box[3]==1 and h.scissor_rect[1]%2==0)end end
view.release();assert(destroyed==5)
print('PASS same-shader role isolation, retained uniform updates, and complete preview GUI cleanup')
