-- One frozen font is used by retained drawing, widths and vertical metrics.
local View=dofile('src/view.lua')
local debug_font='core/performance_hud/debug'
local face={font='1234567890abcdef',material='234567890abcdef1',atlas='34567890abcdef12'}
local descriptor,frame,next_gui,next_id=face,1,0,0
local failure,fail_newer_than,bind_attempts=nil,nil,0
local live_world,width,height={},1920,1080
local texts,bindings,measures,destroyed,resolutions={}, {},{}, {},0
local bad_width,bad_vertical=false,false
local function hex(value)
 if type(value)=='string'then return value end
 assert(value.frame==frame,'Temporary native ID retained across frames');return value.hex
end
local function id()next_id=next_id+1;return next_id end
local sr={
 Application={main_world=function()return live_world end,worlds=function()return {live_world}end,can_get=function(_,value)return value=='preview/material'end},
 IdString64={from_hex=function(value)return {hex=value,frame=frame}end},
 Vector2=function(x,y)return {x=x,y=y}end,Vector3=function(x,y,z)return {x=x,y=y,z=z}end,
 Vector4=function(...)return {...}end,Color=function(...)return {...}end,
 World={create_screen_gui=function(world)next_gui=next_gui+1;return {serial=next_gui,world=world}end,destroy_gui=function(_,gui)assert(gui.world==live_world)end},
 Material={set_texture=function(handle,slot,atlas)
  if failure=='texture_throw'then error('Unavailable texture')end;if failure=='texture_false'then return false end
  assert(handle.gui.world==live_world,'Bound a foreign GUI')
  assert(hex(slot)=='88BAC99B00000000' and hex(atlas)==face.atlas,'Wrong atlas binding');bindings[handle.gui.serial]=hex(atlas)
 end,set_scalar=function()end,set_vector4=function()end},
 Gui={resolution=function()return width,height end,material=function(gui,material)
  if material=='preview/material'then return {gui=gui}end
  bind_attempts=bind_attempts+1
  if failure=='material_throw'then error('Unavailable material')end
  if failure=='material_nil' or (fail_newer_than and gui.serial>fail_newer_than)then return nil end
  if material~='preview/material'then assert(hex(material)==face.material,'Wrong font material')end
  return {gui=gui}
 end,rect=id,triangle=id,
 text=function(gui,label,font,size,material,position)
  font,material=hex(font),hex(material)
  if font==face.font then assert(material==face.material and bindings[gui.serial]==face.atlas,'Text missing its owned atlas')end
  local value=id();texts[#texts+1]={gui=gui.serial,font=font,text=label,material=material,x=position.x,y=position.y,id=value};return value
 end,
 text_extents=function(gui,label,font,size)
  font=hex(font);measures[#measures+1]={font=font,label=label};assert(gui.world==live_world,'Measured dead GUI')
  if bad_width then return {x=0,y=0},{x=0,y=size}end
  if bad_vertical then return {x=0,y=0},{x=#label*size*.45,y=0}end
  local scale=font==face.font and .45 or .7
  local glyphs=0;for _ in label:gmatch('[%z\1-\127\194-\244][\128-\191]*')do glyphs=glyphs+1 end
  local extent=glyphs*size*scale;if label=='AV'then extent=extent-size*.1 end
  return {x=3,y=-size*.2},{x=3+extent,y=size*.7}
 end,
 destroy_text=function(_,value)destroyed[value]=true end,destroy_rect=function(_,value)destroyed[value]=true end,destroy_triangle=function(_,value)destroyed[value]=true end,
 },
}
local view=View.new(sr)
local source={resolve=function()resolutions=resolutions+1;return descriptor end}
local commands={
 {type='text',text='Menu',x=1,y=2,size=12,a=1,c={255,255,255},text_bold=true},
 {type='text',text='Popup',x=1,y=2,size=12,a=1,c={255,255,255},popup=true},
 {type='text',text='Preview',x=1,y=2,size=12,a=1,c={255,255,255},hud_preview=true},
 {type='text',text='Role',x=1,y=2,size=12,a=1,c={255,255,255},hud_preview=true,preview_role='ammo'},
 {type='rect',x=0,y=0,w=10,h=10,a=1,c={255,255,255},hud_preview=true,preview_role='ammo',preview_material='preview/material'},
}
view.set_font_source(source)
assert(not view.refresh_font() and view.font_key==debug_font,'Adopted face before owned GUI ready')
view.draw(commands);assert(#texts==5 and next_gui==4,'GUI plane/bold allocation missing')
for _,text in ipairs(texts)do assert(text.font==debug_font,'Cold paint mixed stock text and game metrics')end
local key=view.metric_key
assert(view.refresh_font() and view.metric_key~=key and view.font_key:find(face.font,1,true),'Warm GUI did not adopt face')
texts={};view.draw(commands)
for _,text in ipairs(texts)do assert(text.font==face.font,'Child/role GUI used different face')end
local last=texts[#texts];local previous=texts[#texts-1]
assert(last.text=='Menu' and previous.text=='Menu' and math.abs(last.x-previous.x-.65)<.0001 and last.y==previous.y,'Bold offset changed physical baseline')
local bold_id=last.id
assert(math.abs(view.measure('AV',20)-19)<.001 and measures[#measures].label=='AV','Whole-string extent/fallback floor regressed')
local vertical=view.text_metrics(20,'Ag0#')
assert(vertical.min_y==-4 and vertical.max_y==14 and vertical.height==18 and vertical.optical_y==-2.4,'HUD vertical metrics unavailable')
local cached=#measures;assert(view.measure('AV',20)==19 and #measures==cached,'Metric cache missed')
bad_width=true;assert(view.measure('To',20)==24.8,'Transient zero did not use fallback');bad_width=false
assert(view.measure('To',20)==21,'Transient zero poisoned width cache')
bad_vertical=true;assert(view.text_metrics(20,'recover').height==20,'Bad vertical metric did not fall back');bad_vertical=false
assert(view.text_metrics(20,'recover').height==18,'Bad vertical metric poisoned cache')
assert(view.measure('\195\169',20)==12,'UTF8 native extent incorrect')
frame=2;assert(not view.refresh_font(),'Same descriptor invalidated GUI');texts={};view.draw(commands);assert(#texts==0,'Unchanged font recreated primitives')
commands[1].text_bold=false;view.draw(commands);assert(destroyed[bold_id],'Retained bold twin leaked after regular text');commands[1].text_bold=true
descriptor=nil;local before=resolutions;view.draw(commands)
assert(resolutions==before and view.measure('AV',20)==19,'Draw refreshed descriptor within composed frame')
assert(view.refresh_font() and view.font_key==debug_font,'Missing descriptor did not fall back')
texts={};view.draw(commands);for _,text in ipairs(texts)do assert(text.font==debug_font,'Fallback retained HUD text')end
assert(view.measure('AV',20)==29,'Fallback retained HUD width')
width,height=0,0;descriptor=face;before=resolutions;cached=#measures
assert(not view.refresh_font() and resolutions==before,'Minimized view resolved font')
assert(view.measure('new',20)>0 and #measures==cached,'Minimized view queried native widths')
width,height=1920,1080;frame=3;assert(view.refresh_font(),'Face did not recover after minimize')
live_world={};texts={};view.draw(commands);assert(#texts==5 and next_gui==8,'World loss retained GUI handles')
assert(view.measure('AV',20)==19,'World loss retained stale metric cache')
local original_face=face
face={font='abcdef1234567890',material='bcdef1234567890a',atlas='cdef1234567890ab'};descriptor=face
key=view.metric_key;cached=#measures
assert(view.refresh_font() and view.metric_key~=key,'Changed descriptor kept old metrics')
texts={};view.draw(commands);assert(#texts==5,'Changed descriptor retained old text handles')
for _,text in ipairs(texts)do assert(text.font==face.font,'Changed descriptor missed a GUI plane')end
assert(view.measure('AV',20)==19 and #measures>cached,'Changed face reused previous metric cache')
face=original_face;descriptor=face;assert(view.refresh_font());view.draw(commands)
view.draw({{type='text',text='Explicit',x=1,y=2,size=12,a=1,c={255,255,255},font_resource='explicit/font',font_material='explicit/material'}})
assert(texts[#texts].font=='explicit/font' and texts[#texts].material=='explicit/material','Explicit face override lost')
view.release()
for _,mode in ipairs({'material_nil','material_throw','texture_throw','texture_false'})do
 failure=nil;view.set_font_source(source);view.draw(commands);assert(view.refresh_font());view.draw(commands)
 failure=mode;assert(view.refresh_font() and view.font_key==debug_font,'Binding failure did not fall back: '..mode)
 local attempts=bind_attempts;assert(not view.refresh_font() and attempts==bind_attempts,'Failed face retried every frame')
 texts={};view.draw(commands);for _,text in ipairs(texts)do assert(text.font==debug_font,'Binding failure mixed drawn/measured font')end
end
failure=nil;view.release()
local other=View.new(sr);other.set_font_source(source);other.refresh_font();other.draw({commands[1]});assert(other.refresh_font());other.draw({commands[1]})
fail_newer_than=next_gui;texts={};other.draw({commands[1],commands[2]});assert(#texts==0,'New popup failure painted mixed fonts')
assert(other.refresh_font() and other.font_key==debug_font,'Child failure did not reach main font state')
other.draw({commands[1],commands[2]});assert(#texts==3,'Fallback missed popup or bold twin')
fail_newer_than=nil;other.release()
descriptor={font=face.font,material=face.material,atlas='bad'}
other.set_font_source(source);other.draw({commands[1]});other.refresh_font();assert(other.font_key==debug_font,'Malformed descriptor accepted');other.release()
-- Production material() queries an assigned GUI instance, not just a loaded
-- resource. A debug-only first paint has no HUD instance. Cover both nil and
-- throwing queries, and never seed an invisible text primitive to create it.
descriptor=face;local original_material=sr.Gui.material
local assigned,creations={},0;local query_throws=false
sr.Gui.material=function(gui,material)
 if material~='preview/material'and not assigned[gui.serial]then
  if query_throws then error('Material not assigned')end;return nil
 end
 return original_material(gui,material)
end
sr.Gui.create_material=function(gui,material)
 assert(gui.world==live_world and hex(material)==face.material,'Created a foreign/unverified font material')
 assert(not assigned[gui.serial],'Created duplicate GUI material')
 assigned[gui.serial]=true;creations=creations+1;return {gui=gui}
end
for _,throws in ipairs({false,true})do
 query_throws=throws;frame=frame+1
 local cold=View.new(sr);cold.set_font_source(source);assert(not cold.refresh_font())
 texts={};cold.draw(commands);for _,text in ipairs(texts)do assert(text.font==debug_font,'Cold material paint used unbound HUD face')end
 local before_creations=creations
 assert(cold.refresh_font()and cold.font_key:find(face.font,1,true),'Unassigned GUI material blocked loaded font adoption')
 assert(creations-before_creations==4,'Did not assign exactly one game material per owned plane')
 texts={};cold.draw(commands)
 for _,text in ipairs(texts)do assert(text.font==face.font,'Assigned face missed an owned GUI plane')end
 assert(cold.measure('AV',20)==19 and creations-before_creations==4,'Assigned font metrics changed or draw duplicated GUI materials')
 frame=frame+1;assert(not cold.refresh_font()and creations-before_creations==4,'Warm refresh recreated assigned materials')
 cold.release()
end
for _,mode in ipairs({'nil','throw'})do
 local attempts=0
 sr.Gui.create_material=function()attempts=attempts+1;if mode=='throw'then error('Creation unavailable')end;return nil end
 local unsupported=View.new(sr);unsupported.set_font_source(source);unsupported.draw({commands[1]})
 unsupported.refresh_font();assert(unsupported.font_key==debug_font,'Failed GUI material assignment did not fall back')
 local before=attempts;unsupported.refresh_font();assert(attempts==before,'Failed material assignment retried unboundedly')
 unsupported.release()
end
sr.Gui.material=original_material;sr.Gui.create_material=nil
print('PASS font rendering: frozen metrics/face, all owned atlas planes, fresh IDs, bold lifetime, transient recovery and safe fallback')
