-- Offline visual fixture: actual registration and menu composition, no storage/game API.
local options=assert(UI_PREVIEW_OPTIONS,'Run this fixture through tools/ui_preview.py')
local root=options.source_root:gsub('\\','/')
local Core=assert(loadfile(root..'/src/core.lua'))()
local Menu=assert(loadfile(root..'/src/menu.lua'))()
local Grouping=assert(loadfile(root..'/src/grouping.lua'))()
local api=Core.new(nil,nil,Grouping)
api.menu_toggle_key=46
local hud=api.register({id='preview_hud',name='DBF HUD',description='Representative preview controls. No installed mod or saved setting is accessed.',
 categories={{id='display',name='Display'},{id='layout',name='Layout',parent='display'},{id='profiles',name='Profiles'}},pages={
 {id='general',name='General',category='display',require_confirmation=false,controls={
  {type='text',text_role='title',label='RETICLE & WEAPON READOUT'},
  {id='enabled',type='toggle',label='Enable HUD',default=true,description='Show your weapon information while playing. Changes take effect immediately.'},
  {id='scale',type='slider',label='HUD scale',min=50,max=150,step=1,default=100,description='Adjust the size of the weapon readout. Click the number to enter an exact value.'},
  {id='opacity',type='slider',label='Background opacity',min=0,max=100,step=1,default=65,description='Set the opacity of the panel behind your weapon information.'},
  {id='style',type='choice',label='Readout style',presentation='combined',choices={'Balanced','Compact','Expanded','Minimal','High contrast','Classic','Weapon-specific','Large type','Custom profile'},default=1,description='Choose how much weapon information appears. Use the arrows or open the list.'},
  {id='accent',type='color',label='Accent color',default='#65CDD2',description='Choose a color, enter RGB or HEX, or reuse a saved swatch.'},
  {id='profile',type='input',label='Profile name',default='Mission ready',description='Use letters, numbers, spaces, underscores or hyphens.'},
  {id='shortcut',type='keybind',label='HUD shortcut',default=72,description='Select this setting, then press a key. Escape cancels the binding.'},
  {id='restore',type='button',label='Restore HUD defaults',button_label='RESTORE DEFAULTS',require_confirmation=false,on_activate=function()return true end,description='Restore the default layout for this example profile.'},
  {id='preview_disabled',type='toggle',label='Controller navigation',default=false,disabled=true,description='Unavailable in this preview fixture.'},
  {type='text',label='Your settings save as you change them.',text_role='body'},
 }},
 {id='layout',name='Position & spacing',category='layout',require_confirmation=false,controls={
  {type='text',text_role='title',label='LAYOUT'},
  {id='horizontal',type='slider',label='Horizontal offset',min=-300,max=300,step=1,default=0,description='Move the readout horizontally.'},
  {id='vertical',type='slider',label='Vertical offset',min=-300,max=300,step=1,default=24,description='Move the readout vertically.'},
  {id='advanced',type='section',label='Advanced spacing',collapsed=false,children={
   {id='padding',type='slider',label='Panel padding',min=0,max=32,step=1,default=12},
   {id='alignment',type='choice',label='Alignment',choices={'Left','Center','Right'},default=2},
  }},
 }},
 {id='confirmation',name='Profile changes',category='profiles',require_confirmation=true,controls={
  {type='text',text_role='title',label='REVIEW BEFORE APPLYING'},
  {type='text',label='These settings remain pending until you apply them. Discard returns to the saved profile.',text_role='body'},
  {id='profile_enabled',type='toggle',label='Use alternate profile',default=false,description='This page stages changes until Apply is selected.'},
  {id='profile_scale',type='slider',label='Alternate scale',min=50,max=150,step=1,default=100,description='The saved value stays unchanged while you review this edit.'},
  {id='profile_style',type='choice',label='Alternate style',presentation='dropdown',choices={'Balanced','Compact','Expanded'},default=1},
 }},
 }})
api.register({id='preview_loader',name='Live Lua Loader',description='Representative manager controls for the offline preview.',pages={
 {id='manager',name='Mod manager',require_confirmation=false,controls={
  {type='text',text_role='title',label='MOD MANAGEMENT'},
  {id='watch',type='toggle',label='Watch mod folders',default=true,description='Refresh the list when mod files change.'},
  {id='refresh',type='button',label='Refresh mod list',button_label='REFRESH',on_activate=function()return true end},
 }},
}})
for _,hex in ipairs({'#F4CA35','#65CDD2','#F1F4F5','#DA7168','#9BBEF0','#749B75'})do assert(api.save_swatch(hex))end

local width,height=options.width or 1920,options.height or 1080
local function fresh(compact)
 local menu=Menu.new(api);menu.visible=true;menu.focus='settings'
 if compact then menu.window_width=1100;menu.window_height=600 end
 return menu
end
local function click_label(menu,label)
 local found
 for _,command in ipairs(menu.compose(width,height))do
  if command.type=='text' and (command.full_text==label or command.text==label)then found=command;break end
 end
 assert(found,'Fixture label not rendered: '..label)
 local down=false
 local input={down=function(code)return code==1 and down end,mouse=function()return found.x+8,found.y+5 end}
 menu.tick(input);down=true;menu.tick(input);down=false;menu.tick(input)
 return menu.compose(width,height)
end
local function expand(menu)click_label(menu,'DBF HUD');menu.focus='settings';menu.row=2 end
local states={}
local function frame(id,label,menu)
 local commands=menu.compose(width,height);assert(#commands>0,'Empty preview frame')
 states[#states+1]={id=id,label=label,commands=commands,window=menu.window_bounds}
end
local preference_path=root..'/src/preferences.lua'
local probe=io.open(preference_path,'rb');local Preferences,preferences,actions
if probe then
 probe:close();Preferences=assert(loadfile(preference_path))();actions={get=function(key)return preferences and preferences.get(key)end,reset_window=function()return 'Preview only'end,open_github=function()return 'No browser launch in preview'end}
 preferences=api.register({id='preview_framework',name='MCM',pages={Preferences.page(function()end,actions)}})
 api.settings_mod_id=preferences.id;api.settings_page_id='mcm_settings'
end
local overview=fresh();expand(overview);frame('overview','General settings',overview)
local dropdown=fresh();expand(dropdown);click_label(dropdown,'Balanced');assert(dropdown.dropdown,'Dropdown did not open');frame('dropdown','Choice dropdown',dropdown)
local color=fresh();expand(color);click_label(color,'#65CDD2');assert(color.color_picker,'Color picker did not open');frame('color','Color picker',color)
local compact=fresh(true);expand(compact);frame('compact','Compact window',compact)
local confirmation=fresh();expand(confirmation);confirmation.key(34);confirmation.key(34)
assert(hud.edit('profile_enabled',true));assert(hud.edit('profile_scale',115));assert(hud.edit('profile_style',2))
frame('confirmation','Pending profile changes',confirmation)
hud.discard('confirmation')
local layout=fresh();expand(layout);layout.key(34);frame('layout','Nested page and sections',layout)

if Preferences then
 local settings=fresh();assert(Preferences.apply(api,settings,preferences,nil,actions));assert(settings.open_settings());frame('settings','MCM shortcuts and window settings',settings)
 settings.wheel(-1200,width*.7,height*.5);frame('settings_actions','Window defaults and GitHub action',settings)
 local large=fresh();preferences.set('font_size',26);preferences.set('ui_scale',125);assert(Preferences.apply(api,large,preferences,nil,actions));expand(large);frame('large_type','Larger font and UI scale',large)
end

local function quoted(value)
 return '"'..value:gsub('[%z\1-\31\\"]',function(char)
  if char=='"'then return '\\"'elseif char=='\\'then return '\\\\'end
  return string.format('\\u%04x',string.byte(char))
 end)..'"'
end
local function json(value)
 local kind=type(value)
 if kind=='nil'then return 'null'elseif kind=='boolean'then return tostring(value)
 elseif kind=='number'then assert(value==value and value~=math.huge and value~=-math.huge,'Nonfinite JSON number');return string.format('%.14g',value)
 elseif kind=='string'then return quoted(value)
 elseif kind=='table'then
  local count,maximum,array=0,0,true
  for key in pairs(value)do count=count+1;if type(key)~='number' or key<1 or key%1~=0 then array=false else maximum=math.max(maximum,key)end end
  local entries={}
  if array and count>0 and count==maximum then for i=1,maximum do entries[#entries+1]=json(value[i])end;return '['..table.concat(entries,',')..']'end
  local keys={};for key in pairs(value)do assert(type(key)=='string','Nonstring JSON object key');keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys)do entries[#entries+1]=quoted(key)..':'..json(value[key])end
  return '{'..table.concat(entries,',')..'}'
 end
 error('Unsupported JSON value: '..kind)
end
UI_PREVIEW_JSON=json({fixture='ui_preview_fixture',width=width,height=height,mod_count=#api.list(),states=states,offline=true,approximate_fonts=true})
