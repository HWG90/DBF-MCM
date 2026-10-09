-- Regression for uneven, grouped Configuration pages such as Epic LUT Settings.
-- Uses only original synthetic registrations and the actual composer/input handlers.
local Core=dofile('src/core.lua')
local override=os.getenv('MCM_RENDER_OVERRIDE')
local Menu=assert(loadfile('src/menu.lua'))(override and {render=assert(loadfile(override))()} or nil)
local passed=0
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed=passed+1;print('PASS '..name)end
local function normal(label)return label:gsub('^%s*',''):gsub('^[v>]%s*','')end
local function labels(commands)
 local found={};for _,c in ipairs(commands)do if c.type=='text'then found[normal(c.full_text or c.text)]=c end end;return found
end
local function fixture(compact)
 local left={'Open basic','Open editor','Shortcuts'};local right={'Gear'};local controls={};local writes=0
 local function toggle(id,label,column)
  return {id=id,type='toggle',label=label,column=column,default=false}
 end
 local function rows(prefix,count,column,expected)
  local result={};for index=1,count do local id=prefix:gsub('%s+','_')..'_'..index;local label=prefix..' '..index
   result[#result+1]=toggle(id,label,column);expected[#expected+1]=label
  end;return result
 end
 for _,entry in ipairs({{'open_basic','Open basic','BASIC'},{'open_editor','Open editor','EDITOR'}})do
  controls[#controls+1]={id=entry[1],type='button',label=entry[2],button_label=entry[3],column=1,on_activate=function()return true end}
 end
 controls[#controls+1]={id='shortcuts',type='section',label='Shortcuts',column=1,collapsed=false,children=rows('Left key',4,1,left)}
 left[#left+1]='Appearance';local appearance=rows('Left look',5,1,left)
 left[#left+1]='Left nested';appearance[#appearance+1]={id='left_nested',type='section',label='Left nested',column=1,collapsed=false,children=rows('Left detail',2,1,left)}
 controls[#controls+1]={id='appearance',type='section',label='Appearance',column=1,collapsed=false,children=appearance}
 controls[#controls+1]={id='gear',type='section',label='Gear',column=2,collapsed=false,children=rows('Right gear',3,2,right)}
 right[#right+1]='Sharing';right[#right+1]='Right status A';right[#right+1]='Right status B';right[#right+1]='Right status C'
 local sharing={{id='status',type='text',column=2,label='Right status A\nRight status B\nRight status C'}}
 local shared=rows('Right sharing',1,2,right);sharing[#sharing+1]=shared[1]
 controls[#controls+1]={id='sharing',type='section',label='Sharing',column=2,collapsed=false,children=sharing}
 right[#right+1]='Updates';controls[#controls+1]={id='updates',type='section',label='Updates',column=2,collapsed=false,children=rows('Right update',4,2,right)}
 right[#right+1]='Manual fallback';local manual=rows('Right file',10,2,right)
 right[#right+1]='Right nested';manual[#manual+1]={id='right_nested',type='section',label='Right nested',column=2,collapsed=false,children=rows('Right detail',4,2,right)}
 controls[#controls+1]={id='manual',type='section',label='Manual fallback',column=2,collapsed=false,children=manual}
 local api=Core.new({load=function()return {}end,save=function()writes=writes+1;return true end})
 local handle=api.register({id='columns',name='Column fixture',pages={{id='settings',name='Configuration',require_confirmation=false,controls=controls}}})
 local menu=Menu.new(api);menu.visible=true;menu.focus='settings';if compact then menu.window_width=1100 end
 local function compose()return menu.compose(1920,1080)end
 local function scroll_to(offset)
  compose();local bounds=menu.window_bounds
  menu.wheel(-120,bounds.x+menu.sidebar_width+100,bounds.y+300)
  menu.scroll=offset;return compose()
 end
 local function click(command)
  local down=false;local input={down=function(code)return code==1 and down end,mouse=function()return command.x+8,command.y+5 end}
  menu.tick(input);down=true;menu.tick(input);down=false;menu.tick(input);return compose()
 end
 return {api=api,handle=handle,menu=menu,left=left,right=right,compose=compose,scroll_to=scroll_to,click=click,writes=function()return writes end}
end
test('both columns remain complete and stable while every expanded control is reached',function()
 local f=fixture();f.compose();local m=f.menu;local visible=m.settings_visible
 assert(#f.left==16 and #f.right==30,'Fixture row accounting changed')
 assert(m.display_total==30,'Viewport counted the flattened registration instead of its column heights')
 local seen={};local maximum=m.display_total-visible
 for offset=0,maximum do
  local found=labels(f.scroll_to(offset));local counts={0,0}
  for column,expected in ipairs({f.left,f.right})do
   local effective=math.min(offset,math.max(0,#expected-visible))
   for line,label in ipairs(expected)do
    local command=found[label];local shown=line>effective and line<=effective+visible
    assert((command~=nil)==shown,'Unexpected visibility at '..offset..': '..label)
    if shown then
     counts[column]=counts[column]+1;seen[label]=true
     local expected_y=m.window_bounds.y+(m.window_height-197-(line-effective-1)*42)*m.window_bounds.scale
     assert(math.abs(command.y-expected_y)<.001,'Row shifted or repacked: '..label)
    end
   end
  end
  assert(counts[1]==visible and counts[2]==visible,'A populated column disappeared during scrolling')
 end
 for _,expected in ipairs({f.left,f.right})do for _,label in ipairs(expected)do assert(seen[label],'Unreachable control: '..label)end end
 local at_zero=labels(f.scroll_to(0));local at_one=labels(f.scroll_to(1))
 for _,label in ipairs({'Left key 2','Right gear 3'})do assert(math.abs(at_one[label].y-at_zero[label].y-42)<.001,'Scrolling did not move one stable row')end
 assert(f.writes()==0,'Scrolling changed settings')
end)
test('wheel and scrollbar range use the longer column while the shorter column stays at bottom',function()
 local f=fixture();f.compose();local m=f.menu;local bounds=m.window_bounds
 for _=1,20 do m.wheel(-120,bounds.x+m.sidebar_width+100,bounds.y+300)end
 assert(m.scroll==#f.right-m.settings_visible,'Wheel did not clamp at the longer column')
 local before=labels(f.scroll_to(#f.left-m.settings_visible));local bottom=labels(f.scroll_to(1000))
 assert(m.scroll==#f.right-m.settings_visible,'Scroll maximum included both columns serially')
 for line=#f.left-m.settings_visible+1,#f.left do local label=f.left[line]
  assert(bottom[label] and math.abs(bottom[label].y-before[label].y)<.001,'Short pane did not remain pinned at its final viewport')
 end
 local thumb;for _,c in ipairs(f.compose())do if c.scrollbar=='settings'then thumb=c end end
 assert(thumb and thumb.h>0,'Settings scroll thumb is missing')
end)
test('right-side pointer edits route to the actual authoritative control',function()
 local f=fixture();local found=labels(f.scroll_to(0));local label=assert(found['Right gear 1'])
 local off
 for _,c in ipairs(f.compose())do if c.type=='text' and c.text=='OFF' and math.abs(c.y-label.y)<.001 and c.x>label.x then off=c end end
 assert(off,'Right toggle value was not rendered beside its label');f.click(off)
 assert(f.handle.get('Right_gear_1')==true and f.handle.get('Left_key_1')==false and f.writes()==1,'Right-side hit edited a different row/owner')
end)
test('keyboard selection scrolls to the right-column line rather than global registration index',function()
 local f=fixture();f.compose();local selectable=0;local target
 for _,c in ipairs(f.api.mods.columns.pages[1].controls)do
  if c.collapsible or (c.type~='text' and c.type~='section')then selectable=selectable+1;if c.id=='Right_detail_4' then target=selectable end end
 end
 assert(target);for _=2,target do f.menu.key(40)end
 local found=labels(f.compose())
 assert(found['Right detail 4'] and f.menu.scroll==#f.right-f.menu.settings_visible,'Right selection used the flattened index to scroll')
 f.menu.row=1;found=labels(f.compose());assert(f.menu.scroll==0 and found['Open basic'],'Keyboard could not return the shorter column to its top')
 assert(f.writes()==0)
end)
test('collapsing a nested pane clamps the shared range and compact layout remains one column',function()
 local f=fixture();local found=labels(f.scroll_to(14));f.click(assert(found['Manual fallback']))
 assert(f.menu.display_total==#f.left and f.menu.scroll<=#f.left-f.menu.settings_visible,'Collapse retained a stale scroll extent')
 found=labels(f.compose());assert(not found['Right file 1'] and not found['Right detail 4'] and found['Left detail 2'],'Collapsed children or short pane were incorrect')
 assert(f.writes()==0)
 local compact=fixture(true);compact.compose();local m=compact.menu
 assert(m.display_total==#compact.left+#compact.right,'Compact layout retained two-column extent')
 local expected={};for _,list in ipairs({compact.left,compact.right})do for _,label in ipairs(list)do expected[#expected+1]=label end end
 local seen={}
 for offset=0,m.display_total-m.settings_visible do
  local shown=labels(compact.scroll_to(offset))
  for line,label in ipairs(expected)do
   local visible=line>offset and line<=offset+m.settings_visible
   assert((shown[label]~=nil)==visible,'Compact viewport failed at '..offset..': '..label)
   if visible then seen[label]=true end
  end
 end
 for _,label in ipairs(expected)do assert(seen[label],'Compact control was unreachable: '..label)end
 assert(compact.writes()==0)
end)
print(string.format('PASS %d multi-column contracts: expanded rows, stable scrolling, pinned short pane, hits, keyboard, collapse and compact mode',passed))
