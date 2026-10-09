-- Framework-owned MCM preferences. This module never creates another registration.
local P={}
local defaults={menu_toggle_key=46,
 window_width=1500,window_height=820,ui_scale=100,font_size=20}
local ranges={window_width={1100,1920},window_height={600,1080},ui_scale={75,150},font_size={16,26}}
local reserved={[9]=true,[13]=true,[16]=true,[17]=true,[18]=true,[27]=true,[33]=true,[34]=true,
 [37]=true,[38]=true,[39]=true,[40]=true,[91]=true,[92]=true,[160]=true,[161]=true,[162]=true,[163]=true,[164]=true,[165]=true}
local function copy(value)local result={};for key,item in pairs(value)do result[key]=item end;return result end
function P.defaults()return copy(defaults)end
function P.valid_key(value)
 return type(value)=='number' and value==value and value%1==0 and value>=8 and value<=254 and not reserved[value]
end
function P.validate_key(key,value)
 assert(key=='menu_toggle_key','Unknown MCM shortcut')
 assert(P.valid_key(value),'Use a keyboard key other than Escape, navigation or modifier keys')
 return true
end
-- Restore a damaged open/close binding through its existing owner.
function P.normalize_keys(values)
 local value=values.menu_toggle_key
 if P.valid_key(value)then return {menu_toggle_key=value},{},nil end
 return {menu_toggle_key=defaults.menu_toggle_key},{menu_toggle_key=defaults.menu_toggle_key},'Invalid MCM open / close key was restored to Delete'
end
local function read(handle)
 assert(type(handle)=='table' and type(handle.get)=='function','Framework settings handle required')
 local values={};for key in pairs(defaults)do values[key]=handle.get(key)end
 for key,range in pairs(ranges)do local value=values[key]
  assert(type(value)=='number' and value==value and value>=range[1] and value<=range[2],'Invalid MCM setting: '..key)
 end
 return values
end
function P.page(on_change,actions)
 assert(type(on_change)=='function','Preference change callback required');actions=actions or {}
 local function key(id,label,description)
  return {id=id,type='keybind',label=label,description=description,default=defaults[id],
   validate=function(value)return P.validate_key(id,value)end,
   on_change=function(value,changed_id)return on_change(changed_id,value)end}
 end
 local function slider(id,label,step,description)
  return {id=id,type='slider',label=label,description=description,min=ranges[id][1],max=ranges[id][2],step=step,default=defaults[id],
   on_change=function(value,changed_id)return on_change(changed_id,value)end}
 end
 return {id='mcm_settings',name='Settings',require_confirmation=false,controls={
  {id='mcm_shortcuts',type='section',label='Menu shortcut',collapsed=false,children={
   key('menu_toggle_key','Open / close menu','Select, then press a key. Delete is the default; Escape always closes the menu.'),
  }},
  {id='mcm_window',type='section',label='Window and text',collapsed=false,children={
   slider('window_width','Window width',10,'Preferred window width before UI scaling. Dragging the window edges remains available.'),
   slider('window_height','Window height',10,'Preferred window height before UI scaling. The window stays within the current screen.'),
   slider('ui_scale','UI scale (%)',5,'Scale the complete menu. 100% uses the default size.'),
   slider('font_size','Font size',1,'Base menu text size. Headings and labels follow this setting; 20 is the default.'),
  }},
  {id='reset_window',type='button',label='Reset size and position',button_label='RESET WINDOW',require_confirmation=false,
   description='Restore your saved preferred size and center the window.',disabled=type(actions.reset_window)~='function',
   on_activate=actions.reset_window or function()return 'Window reset is unavailable'end},
  {id='github_page',type='button',label='GitHub Page',button_label='OPEN GITHUB',require_confirmation=false,
   description='Open the MCM GitHub page in your default browser.',disabled=type(actions.open_github)~='function',
   on_activate=actions.open_github or function()return 'GitHub action is unavailable'end},
 }}
end
-- Repair through the same owning handle; failed persistence never changes runtime state.
function P.repair_keys(handle)
 local called,values=pcall(read,handle);if not called then return false,tostring(values)end
 local normalized,changes,notice=P.normalize_keys(values)
 if not next(changes)then return true,nil,normalized end
 if type(handle.set)~='function'then return false,'Invalid MCM shortcut requires the framework repair action'end
 local invoked,ok,err=pcall(handle.set,'menu_toggle_key',normalized.menu_toggle_key)
 if not invoked then return false,tostring(ok)end
 if not ok then return false,tostring(err or 'Could not save the repaired MCM shortcut')end
 return true,notice,normalized
end
function P.apply(api,menu,handle,changed_key,actions)
 local called,values=pcall(read,handle);if not called then return false,tostring(values)end
 local keys,changes,notice=P.normalize_keys(values)
 if next(changes)then
  if changed_key then return false,'Invalid MCM open / close key'end
  local ok,err,repaired=P.repair_keys(handle);if not ok then return false,err end
  notice=err;keys=repaired
 end
 api.menu_toggle_key=keys.menu_toggle_key
 api.ui_keys={}
 menu.ui_scale=values.ui_scale/100;menu.font_scale=values.font_size/20
 menu.default_window_width=values.window_width;menu.default_window_height=values.window_height
 if changed_key==nil or changed_key=='window_width'then menu.window_width=values.window_width end
 if changed_key==nil or changed_key=='window_height'then menu.window_height=values.window_height end
 return true,notice
end
function P.reset_window(menu,handle)
 local called,values=pcall(read,handle);if not called then return false,tostring(values)end
 menu.default_window_width=values.window_width;menu.default_window_height=values.window_height
 menu.window_width=values.window_width;menu.window_height=values.window_height
 menu.window_x=nil;menu.window_y=nil;menu.window_bounds=nil
 return true,'Window size and position reset'
end
return P
