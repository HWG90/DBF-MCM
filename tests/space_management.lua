-- Composer contracts: spend label room up to the existing control, not a fixed reserve.
local preview=rawget(_G,'SPACE_MANAGEMENT_PREVIEW')
local source=preview and preview.source_root or '.'
local Core=assert(loadfile(source..'/src/core.lua'))()
local Menu=assert(loadfile(source..'/src/menu.lua'))()
local Text=assert(loadfile(source..'/src/ui/text.lua'))()
local View=assert(loadfile(source..'/src/view.lua'))()
local count=0
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));count=count+1;print('PASS '..name)end
local function metric(factor)
 return function(value,size)
  local _,av=value:gsub('AV','');local _,to=value:gsub('To','')
  return math.max(0,(#value*.55-(av+to)*.12)*size*factor)
 end
end
local definitions={
 {id='enabled',type='toggle',label='Always populate all LUT slots from currently equipped gear',default=false},
 {id='binding',type='keybind',label='Open the advanced editor and configuration interface',default=46},
 {id='filename',type='input',label='Saved outfit filename without the extension or folder',default='mission_ready'},
 {id='highlight',type='color',label='Highlight color for the active equipment selection',default='#123456'},
 {id='opacity',type='slider',label='Player preview panel opacity and background strength',min=0,max=100,step=1,default=50},
 {id='format',type='choice',label='Resource identifier display and import presentation',choices={'Hexadecimal','Decimal'},default=1,presentation='combined'},
 {id='profile',type='choice',label='Import and preview profile used for current equipment',choices={'Default profile','Mission ready'},default=1,presentation='dropdown'},
 {id='open_editor',type='button',label='Open the advanced LUT editor for the selected equipment',button_label='OPEN EDITOR',on_activate=function()return true end},
 {id='outfit',type='choice',label='Select the current outfit and sharing preset profile',choices={'Current outfit','Alternate outfit'},default=1,presentation='selector'},
}
local function fixture(width,font_scale,columns,factor)
 local controls={};local writes=0
 for index,original in ipairs(definitions)do local c={};for key,value in pairs(original)do c[key]=value end
  c.column=columns and (index<=5 and 1 or 2) or nil;controls[#controls+1]=c
 end
 local pages={{id='configuration',name='Configuration - Equipment and Preview Preferences',category='configuration',require_confirmation=false,controls=controls}}
 for index=1,22 do pages[#pages+1]={id='page_'..index,name='Equipment Configuration Page '..index..' - Additional Presentation Settings',category='nested',controls={}}end
 local api=Core.new({load=function()return {}end,save=function()writes=writes+1;return true end})
 local name='Epic LUT Settings - Equipment and Configuration Preferences'
 local handle=api.register({id='epic',name=name,categories={{id='configuration',name='Configuration and Presentation Preferences'},{id='nested',parent='configuration',name='Nested Equipment and Preview Configuration'}},pages=pages})
 for index=1,3 do api.register({id='other_'..index,name='ZZ Additional HUD and Equipment Configuration '..index,pages={{id='settings',name='Settings',controls={}}}})end
 local measure=metric(factor or 1);local menu=Menu.new(api,measure)
 menu.visible=true;menu.focus='settings';menu.window_width=width;menu.font_scale=font_scale
 local function compose()return menu.compose(1920,1080)end
 local function find(label,sidebar)
  for _,c in ipairs(compose())do if c.type=='text' and c.full_text==label and (not sidebar or c.x<menu.window_bounds.x+menu.sidebar_width)then return c end end
 end
 local function click(x,y)
  local down=false;local input={down=function(code)return code==1 and down end,mouse=function()return x,y end}
  menu.tick(input);down=true;menu.tick(input);down=false;menu.tick(input);return compose()
 end
 local selected=find(name,true);assert(selected);click(selected.x+4,selected.y+4);menu.focus='settings'
 return {api=api,handle=handle,menu=menu,measure=measure,compose=compose,find=find,click=click,writes=function()return writes end}
end
local function row_bounds(commands,label,s)
 for _,c in ipairs(commands)do if c.ui_role=='setting_row' and label.y>=c.y and label.y<=c.y+c.h and math.abs(c.x+5*s-label.x)<.001 then return c.x+c.w,c end end
 error('Missing setting row bounds')
end
local function control_left(commands,c,label,right,s)
 local left
 local _,row=row_bounds(commands,label,s);local row_y=row.y+7*s
 for _,shape in ipairs(commands)do if shape.type=='rect' and shape.ui_role~='setting_row' and shape.x>=label.x and shape.x<right then
  local h=shape.h/s;local y=(shape.y-row_y)/s
  if c.type=='slider' and shape.ui_role=='slider_track'and math.abs(y-4)<.01 then return shape.x-8*s end
  if c.type=='color' and math.abs(shape.w/s-34)<.01 and math.abs(h-23)<.01 and math.abs(y+3)<.01 then return shape.x-5*s end
  if (c.type=='toggle' or c.type=='keybind')and math.abs(shape.w/s-175)<.01 and math.abs(h-29)<.01 and math.abs(y+5)<.01 then left=shape.x end
  if c.type=='input'and shape.ui_role=='control_fill'and math.abs(h-29)<.01 and math.abs(y+5)<.01 then left=shape.x end
  if (c.type=='choice' or c.type=='button')and (math.abs(h-29)<.01 or math.abs(h-31)<.01 or math.abs(h-33)<.01)and y>=-7.01 and y<=-4.99 then left=left and math.min(left,shape.x)or shape.x end
 end end
 assert(left,'Missing actual control shape: '..c.id);return left
end
if preview then
 local states={}
 for _,case in ipairs({{id='full',label='Full-width Configuration',width=1500,font=1,columns=false},{id='columns',label='Two-column Configuration',width=1500,font=1,columns=true},{id='narrow',label='Narrow window / large font',width=1100,font=1.3,columns=true}})do
  local f=fixture(case.width,case.font,case.columns,1);states[#states+1]={id=case.id,label=case.label,commands=f.compose()}
 end
 local function quote(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)if c=='"'then return '\\"'elseif c=='\\'then return '\\\\'end;return string.format('\\u%04x',c:byte())end)..'"'end
 local function json(v)
  if type(v)=='string'then return quote(v)elseif type(v)=='boolean'then return tostring(v)elseif type(v)=='number'then return string.format('%.14g',v)
  elseif type(v)=='table'then local parts={};if #v>0 then for _,value in ipairs(v)do parts[#parts+1]=json(value)end;return '['..table.concat(parts,',')..']'end
   local keys={};for key in pairs(v)do keys[#keys+1]=key end;table.sort(keys);for _,key in ipairs(keys)do parts[#parts+1]=quote(key)..':'..json(v[key])end;return '{'..table.concat(parts,',')..'}'
  end;return 'null'
 end
 SPACE_MANAGEMENT_PREVIEW_JSON=json({width=1920,height=1080,states=states});return
end
test('aligned label extents use their clamped lane without overlapping control hit edges',function()
 for _,factor in ipairs({.72,1,1.15})do
  for _,case in ipairs({{1500,1,false},{1500,1,true},{1920,1.3,true},{1100,1,false},{1100,1.3,true}})do
   local f=fixture(case[1],case[2],case[3],factor);local commands=f.compose();local s=f.menu.window_bounds.scale
   for _,c in ipairs(definitions)do
    local label=assert(f.find(c.label),'Missing label '..c.id);local right=row_bounds(commands,label,s)
    local edge=control_left(commands,c,label,right,s);local gap=(edge-label.x-label.text_width)/s
    assert(gap>=7.99 and gap<=16.01,'Unused/overlapping label room '..c.id..' gap='..gap)
    assert(f.measure(label.text,label.size)<=label.text_width+.001,'Rendered label overlaps its control: '..c.id)
    if #label.text<#label.full_text then local next_glyph=label.full_text:sub(#label.text+1,#label.text+1)
     assert(f.measure(label.text..next_glyph,label.size)>label.text_width-.001,'Label clipped before its available room: '..c.id)
    end
   end
   assert(f.writes()==0)
  end
 end
end)
test('long sidebar labels stay before the scrollbar gutter with full-string metrics',function()
 for _,factor in ipairs({.72,1,1.15})do local f=fixture(1500,1.3,true,factor);local b=f.menu.window_bounds
  local count=0
  for _,c in ipairs(f.compose())do if c.type=='text' and c.full_text and c.x<b.x+f.menu.sidebar_width and c.y>b.y+196 and c.y<b.y+(f.menu.window_height-125)*b.scale then
   count=count+1;assert(c.x+c.text_width<=b.x+(f.menu.sidebar_width-15)*b.scale+.001,'Sidebar reserved area overlaps its scrollbar')
   assert(c.x+f.measure(c.text,c.size)<=b.x+(f.menu.sidebar_width-15)*b.scale+.001,'Sidebar text overlaps its scrollbar')
  end end
  assert(count>=3,'Nested sidebar was not exercised')
 end
end)
test('aligned control hit targets still edit their own owners after label fitting',function()
 for _,case in ipairs({{1500,1,false},{1500,1,true},{1920,1.3,true},{1100,1.3,true}})do
  local f=fixture(case[1],case[2],case[3],1);local commands=f.compose();local s=f.menu.window_bounds.scale
  local toggle=f.find(definitions[1].label);local right=row_bounds(commands,toggle,s)
  local toggle_left=control_left(commands,definitions[1],toggle,right,s)
  f.click(toggle_left+80*s,toggle.y+5*s);assert(f.handle.get('enabled')==true and f.writes()==1)
  local choice=f.find(definitions[6].label);commands=f.compose();right=row_bounds(commands,choice,s)
  local choice_left=control_left(commands,definitions[6],choice,right,s);local _,row=row_bounds(commands,choice,s)
  for _,command in ipairs(commands)do if command.type=='text'and(command.text=='<'or command.text=='>')and command.x>choice.x and command.x<right and command.y>=row.y and command.y<=row.y+row.h then
   error('Dropdown retained a redundant selector arrow')
  end end
  f.click(choice_left+40*s,choice.y+5*s);assert(f.menu.dropdown and f.handle.get('format')==1 and f.writes()==1,'Dropdown field hit immediately cycled or edited another owner')
  local d=f.menu.dropdown;assert(math.abs(f.menu.window_bounds.x+d.x*s-choice_left)<.001,'Popup anchor disagrees with its field')
  assert(d.width<=f.menu.layout_geometry.row_width-f.menu.layout_geometry.control_offset,'Dropdown width retains hidden selector padding')
  f.menu.key(40);f.menu.key(13);assert(f.handle.get('format')==2 and f.handle.get('profile')==1 and f.writes()==2,'Dropdown accepted another owner or wrote twice')
  f.menu.key(37);assert(f.handle.get('format')==1 and f.writes()==3,'Keyboard cycling stopped working after selector removal')
  choice=f.find(definitions[9].label);commands=f.compose();right,row=row_bounds(commands,choice,s)
  local arrow
  for _,command in ipairs(commands)do if command.type=='text'and command.text=='>'and command.x>choice.x and command.x<right and command.y>=row.y and command.y<=row.y+row.h then arrow=command end end
  assert(arrow,'Explicit selector arrow missing');f.click(arrow.x+2*s,arrow.y+2*s)
  assert(f.handle.get('outfit')==2 and not f.menu.dropdown and f.writes()==4,'Explicit selector changed its authored cycle-only contract')
 end
end)
test('text helpers use whole-string kerning and native view metrics without a fallback floor',function()
 local measured=metric(1);local value='AVAV';local width=measured(value,20)
 local text,clipped=Text.flow(value,width,20,0,measured);assert(text==value and not clipped,'Full-string extent was replaced with glyph sums')
 assert(math.abs(Text.control_width(value,0,100,0,20,measured)-width)<.001,'Choice/button width ignored full-string extents')
 local world={};local queries={};local sr={Application={main_world=function()return world end,worlds=function()return {world}end},World={create_screen_gui=function()return {}end,destroy_gui=function()end},Gui={},Vector3=function(x,y,z)return {x=x,y=y,z=z}end,Vector2=function(x,y)return {x=x,y=y}end,Color=function(...)return {...}end}
 sr.Gui.rect=function()return 1 end;sr.Gui.destroy_rect=function()end
 local zero_once=true
 sr.Gui.text_extents=function(_,string_value,_,size)
  queries[#queries+1]=string_value
  if string_value=='To' and zero_once then zero_once=false;return {x=0,y=0},{x=0,y=size}end
  return {x=3,y=0},{x=3+measured(string_value,size)*.5,y=size}
 end
 local view=View.new(sr,true);view.draw({{type='rect',x=0,y=0,w=1,h=1,c={0,0,0},a=1}})
 assert(math.abs(view.measure(value,20)-(3+width*.5))<.001,'Native origin/right extent was floored by an approximate fallback')
 assert(queries[#queries]==value,'Native measurement queried an M-prefixed substitute')
 local first=view.measure('To',20);local second=view.measure('To',20)
 assert(first>0 and math.abs(second-(3+measured('To',20)*.5))<.001,'Transient zero poisoned cached native width')
 local before=#queries;assert(view.measure('To',20)==second and #queries==before,'Successful native metric was not cached')
 view.release()
end)
print(string.format('PASS %d space-management contracts: full label budgets, exact metrics, sidebar gutter and unchanged owner hits',count))
