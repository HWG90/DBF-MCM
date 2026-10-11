-- Retained hover redraws keep overlays above fields without creation-order tricks.
local View=dofile('src/view.lua')
local world={};local serial=0;local next_id=0;local primitives={};local removed={};local allocated=0
local function allocation(gui,kind,layer,data)
 next_id=next_id+1;allocated=allocated+1
 primitives[next_id]={gui=gui,type=kind,layer=layer,data=data};return next_id
end
local function destroy(_,value)if value then assert(primitives[value],'Destroyed an unrelated/reused native ID');primitives[value]=nil;removed[value]=true end end
local sr={Application={main_world=function()return world end,worlds=function()return {world}end},World={
 create_screen_gui=function()serial=serial+1;return serial end,destroy_gui=function(_,gui)for _,p in pairs(primitives)do assert(p.gui~=gui,'GUI release leaked a retained primitive')end end},
 Vector2=function(x,y)return {x=x,y=y}end,Vector3=function(x,y,z)return {x=x,y=y,z=z}end,Color=function(...)return {...}end,
 Gui={rect=function(gui,position,size,color)return allocation(gui,'rect',position.z,{position=position,size=size,color=color})end,
 text=function(gui,value,_,_,_,position)return allocation(gui,'text',position.z,{value=value,position=position})end,
 triangle=function(gui,a,b,c,layer,color,material)
  assert(material==nil,'Solid icon unexpectedly requires a game asset')
  assert(a.y==0 and b.y==0 and c.y==0,'Triangle used rectangle X/Y convention')
  return allocation(gui,'triangle',layer,{a=a,b=b,c=c,color=color})
 end,destroy_text=destroy,destroy_rect=destroy,destroy_triangle=destroy}}
local view=View.new(sr)
local fill={type='rect',x=20,y=20,w=80,h=30,c={25,28,30},a=1,layer=100,ui_role='control_fill'}
local mark={type='triangle',points={65,25,85,25,75,40},c={250,220,0},a=1,layer=104,ui_role='control_icon'}
local label={type='text',text='Enabled',x=25,y=25,size=20,c={255,255,255},a=1,layer=102}
local commands={fill,mark,label}
view.draw(commands)
local mark_id,label_id
for id,p in pairs(primitives)do if p.type=='triangle'then mark_id=id elseif p.type=='text'then label_id=id end end
assert(primitives[mark_id].layer==104 and primitives[label_id].layer==103,'Explicit field/ink lanes changed')
fill.c={55,60,62};view.draw(commands)
assert(primitives[mark_id] and primitives[label_id],'Hover recreated unchanged overlay primitives')
for _,p in pairs(primitives)do if p.type=='rect'then assert(p.layer<primitives[mark_id].layer and p.layer<primitives[label_id].layer,'Repainted field covered retained icon or label')end end
local before=allocated;view.draw(commands);assert(before==allocated,'Unchanged retained scene repainted')
mark.points={65,25,90,25,75,40};view.draw(commands)
assert(removed[mark_id] and primitives[label_id],'Triangle geometry cache missed or removed unrelated text')
local changed_id
for id,p in pairs(primitives)do if p.type=='triangle'then changed_id=id;assert(p.data.b.x==90 and p.data.c.z==40,'Triangle points changed or lost screen coordinates')end end
-- Popup and preview-role icons use owned GUI planes, and explicit layer
-- depth never depends on the changing number of preceding sidebar commands.
local popup={type='triangle',points={100,100,120,100,110,120},c={250,220,0},a=1,layer=344,popup=true}
local preview={type='triangle',points={130,100,150,100,140,120},c={250,220,0},a=1,layer=114,hud_preview=true,preview_role='badge'}
commands[#commands+1]=popup;commands[#commands+1]=preview;view.draw(commands)
local main_gui=primitives[changed_id].gui;local popup_gui,preview_gui
for _,p in pairs(primitives)do if p.layer==344 then popup_gui=p.gui elseif p.layer==114 then preview_gui=p.gui end end
assert(popup_gui and preview_gui and popup_gui~=main_gui and preview_gui~=main_gui and popup_gui~=preview_gui,'Triangle borrowed another plane')
table.insert(commands,1,{type='rect',x=0,y=0,w=1,h=1,c={1,1,1},a=1,layer=90});view.draw(commands)
for _,p in pairs(primitives)do if p.type=='text'then assert(p.layer==103,'Sidebar count shifted field text depth')end end
view.release();assert(next(primitives)==nil,'Triangle/native text leaked at release')
-- Decorative triangles are optional; a stripped GUI API or invalid geometry
-- must not be interpreted as text or close the usable menu.
sr.Gui.triangle=nil
local fallback=View.new(sr,true)
fallback.draw({fill,mark,{type='triangle',points={0,0,1,1,0/0,2},c={255,0,0},a=1,layer=104}})
for _,p in pairs(primitives)do assert(p.type=='rect','Unavailable/invalid triangle escaped fail-safe path')end
fallback.release();assert(next(primitives)==nil)
print('PASS retained GUI layers: hover-safe field/ink lanes, cached vector icons, absolute X/Z points, popup/preview ownership and cleanup')
