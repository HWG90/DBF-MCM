-- Shared diagnostics and typed command input; borrows the parent menu's input lease.
local M={}
local levels={debug=true,info=true,warn=true,error=true}
local function bounded(value,limit)
    local text=tostring(value or ''):gsub('%z',''):gsub('[\1-\8\11\12\14-\31]',' ')
    if #text>limit then
        while limit>0 and text:byte(limit+1)>=128 and text:byte(limit+1)<=191 do limit=limit-1 end
        text=text:sub(1,limit)..' [truncated]'
    end
    return text
end
-- A per-mod sink uses an existing log directory; it never creates directories.
function M.owner_logger(directory,options)
    options=options or {};local open=options.open or io.open;local clock=options.clock or function()return os.date('%Y-%m-%d %H:%M:%S')end
    return function(owner,message,level)
        if type(owner)~='string'or #owner>80 or not owner:match('^[%w_-]+$')then return false,'Invalid stable ID'end
        if type(directory)~='string'or directory==''or directory:find('[%z\r\n]')then return false,'Log directory unavailable'end
        local path=directory..(directory:match('[/\\]$')and ''or '/')..'MCM-'..owner..'.log'
        local ok,file,why=pcall(open,path,'a');if not ok then return false,file end;if not file then return false,why or 'Cannot open mod log'end
        local wrote,result,write_error=pcall(function()
            local timestamp,stamp=clock();stamp=type(stamp)=='string'and stamp or timestamp
            local severity=levels[level]and level or 'error'
            return file:write(bounded(stamp,96)..' '..severity:upper()..' '..bounded(message,8192):gsub('[\r\n]',' ')..'\n')
        end)
        local closed,close_result,close_error=pcall(function()return file:close()end)
        if not wrote then return false,result end
        if not result then return false,write_error or 'Cannot write mod log'end
        if not closed then return false,close_result end
        if not close_result then return false,close_error or 'Cannot close mod log'end
        return true,path
    end
end
function M.new(options)
    options=options or {}
    local capacity=math.max(16,math.min(512,options.capacity or 256))
    local ring,first,count,sequence={},1,0,0
    local owners={};local clock=options.clock or function()return os.time(),os.date('%H:%M:%S')end
    local api={api=1,revision=0,capacity=capacity,count=0,locations={},window={visible=false,width=740,height=320,scroll=0,dock='free'}}
    function api.emit(event)
        assert(type(event)=='table','Diagnostics event required')
        local source=bounded(event.source or 'Unknown',96)
        local severity=levels[event.severity] and event.severity or 'info'
        local message=bounded(event.message,1024);local details=bounded(event.details,1536)
        local path=bounded(event.log_path or api.locations[source],512)
        local timestamp,time=clock()
        local last=count>0 and ring[(first+count-2)%capacity+1]
        if last and last.source==source and last.severity==severity and last.message==message and last.details==details and last.log_path==path then
            last.repeats=last.repeats+1;last.timestamp=timestamp;last.time=time
        else
            sequence=sequence+1
            local index=(first+count-1)%capacity+1
            if count==capacity then index=first;first=first%capacity+1 else count=count+1 end
            ring[index]={seq=sequence,timestamp=timestamp,time=time,source=source,severity=severity,message=message,details=details,log_path=path,repeats=1}
        end
        api.count=count;api.revision=api.revision+1
        return sequence
    end
    function api.record(source,message,severity,details,path)
        if not severity then
            local lower=tostring(message):lower()
            severity=(lower:find('failed',1,true) or lower:find('error',1,true) or lower:find('refused',1,true)) and 'error'
                or (lower:find('pending',1,true) or lower:find('warning',1,true)) and 'warn'
                or tostring(message):match('^MCM TEXT') and 'debug' or 'info'
        end
        return api.emit({source=source,severity=severity,message=message,details=details,log_path=path})
    end
    function api.read()
        local result={}
        for i=1,count do local item=ring[(first+i-2)%capacity+1];local copy={};for k,v in pairs(item)do copy[k]=v end;result[i]=copy end
        return result
    end
    function api.attach(source,path)
        source=bounded(source,96);local token={};owners[token]=source
        if path and path~='' then api.locations[source]=bounded(path,512)end
        return token
    end
    function api.detach(token)
        if not owners[token]then return false,'Unknown diagnostics owner'end
        owners[token]=nil
        if not next(owners)then api.window.visible=false;api.window.focused=false;api.window.input_focused=false;api.window.drag=nil;api.window.resize=nil;api.active_surface=nil end
        return true
    end
    return api
end
function M.shared(provider)
    local key='dbf.diagnostics.v1';local value=provider or rawget(_G,'DBFDiagnostics') or package.loaded[key]
    if value then assert(value.api==1 and type(value.emit)=='function' and type(value.attach)=='function','Incompatible diagnostics provider')
    else value=M.new()end
    package.loaded[key]=value;rawset(_G,'DBFDiagnostics',value)
    return value
end
local colors={debug={145,156,165},info={224,230,234},warn={244,202,53},error={255,116,116}}
local function wrap(value,width)
    local lines={};local current='';local size=0
    for glyph in tostring(value):gmatch('[%z\1-\127\194-\244][\128-\191]*')do
        if glyph=='\n' then lines[#lines+1]=current;current='';size=0
        else if size>=width then lines[#lines+1]=current;current='';size=0 end;current=current..glyph;size=size+1 end
    end
    if current~=''then lines[#lines+1]=current end
    return lines
end
local function continuation(byte)return byte and byte>=128 and byte<=191 end
local function backspace(value)
    local last=#value;while last>1 and continuation(value:byte(last))do last=last-1 end
    return value:sub(1,last-1)
end
local function tail(value,count)
    local first=#value+1
    for _=1,count do
        if first<=1 then break end
        first=first-1;while first>1 and continuation(value:byte(first))do first=first-1 end
    end
    return value:sub(first)
end
local function prefix(value,count)
    local first=1
    for _=1,count do
        if first>#value then break end
        first=first+1;while continuation(value:byte(first))do first=first+1 end
    end
    return value:sub(1,first-1)
end
local neutral={background={17,22,27},header={31,38,44},field={29,39,47},field_hover={40,55,65},line={43,53,61},focus={119,185,205},selected={38,53,63},brass={221,184,105},muted={153,166,175},white={231,236,239}}
-- Command interaction follows maintained LLL src/ui/diagnostics.lua; no Lua evaluator.
function M.surface(model,options)
    assert(model and model.api==1,'Diagnostics provider required')
    options=options or {};local palette={};for key,value in pairs(neutral)do palette[key]=options.palette and options.palette[key]or value end
    local toggle_key=options.toggle_key;if toggle_key==nil then toggle_key=192 end
    assert(toggle_key==false or type(toggle_key)=='number'and toggle_key%1==0 and toggle_key>=8 and toggle_key<=255,'Invalid console toggle key')
    local self={};local token={};local hits={};local bounds,parent,screen;local held={};local mouse_held=false;local editing_last=false
    local cache={};local lines={};local cached_revision=-1;local cached_width=-1;local visible=1;local repeats={};local focus_requested=false
    local state=model.window;local explicitly_open=false
    -- Hosts share diagnostics/history; MCM chooses when its own surface opens.
    local function shown()return state.visible and (not options.explicit_open or explicitly_open)end
    local function inside(x,y,b)return b and x and y and x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h end
    local function release_drag()if state.drag and state.drag.owner==token then state.drag=nil end;if state.resize and state.resize.owner==token then state.resize=nil end end
    function self.release()
        release_drag();repeats={};focus_requested=false;explicitly_open=false
        if model.active_surface==token then state.input_focused=false;state.focused=false;model.active_surface=nil end
        hits={};bounds=nil;self.bounds=nil
    end
    local function scroll(amount,absolute)
        local maximum=math.max(0,#lines-visible)
        state.scroll=math.max(0,math.min(maximum,absolute or (state.scroll+amount)));state.anchor=nil
    end
    state.command_text=state.command_text or '';state.command_history=state.command_history or {}
    local suggestions={};local suggestion_text,suggestion_bus,suggestion_ready;local selected=1;local dismissed
    local function valid_suggestion(value,limit)return type(value)=='string'and #value>0 and #value<=limit and not value:find('[%c]')end
    local function refresh_suggestions()
        local bus=model.commands
        if suggestion_text~=state.command_text or suggestion_bus~=bus then
            suggestion_text,suggestion_bus=state.command_text,bus;selected=1;dismissed=nil;suggestion_ready=false;suggestions={}
        end
        if not shown()or not state.input_focused or dismissed or state.command_text==''then suggestions={};return end
        if suggestion_ready then return end
        suggestion_ready=true;suggestions={}
        local suggest=type(bus)=='table'and rawget(bus,'suggest')
        if type(suggest)=='function'then
            local ok,items=pcall(suggest,state.command_text)
            if ok and type(items)=='table'then
                for index=1,64 do
                    local item=rawget(items,index);if item==nil then break end
                    if type(item)=='table'then
                        local value,label=rawget(item,'text'),rawget(item,'label')
                        if valid_suggestion(value,1024)and valid_suggestion(label,512)then suggestions[#suggestions+1]={text=value,label=label}end
                    end
                end
            elseif not ok then self.notice='Command suggestions unavailable'end
        end
        selected=math.max(1,math.min(#suggestions,selected))
    end
    local function complete(index)
        local item=suggestions[index or selected]
        if not item then return false end
        state.command_text=item.text;state.replace_input=false;suggestion_text=item.text;dismissed=true;suggestions={};suggestion_ready=true
        return true
    end
    function self.focus()
        explicitly_open=true;state.visible=true;state.focused=true;state.input_focused=true;state.suppress_input=true;focus_requested=true;repeats={};suggestion_ready=false
        return true
    end
    function self.command_state()
        refresh_suggestions();local copied={};for index,item in ipairs(suggestions)do copied[index]={text=item.text,label=item.label}end
        return {text=state.command_text,suggestions=copied,selected=selected,editing=shown()and state.input_focused==true}
    end
    function self.submit()
        local command=state.command_text:match('^%s*(.-)%s*$')
        if command==''then return false,'Enter a command'end
        local bus=model.commands;local execute=type(bus)=='table'and rawget(bus,'execute')
        local ok,message=false,'Console command service unavailable'
        if type(execute)=='function'then
            local called,result,detail=pcall(execute,command)
            if called then ok,message=result==true,detail else message=result end
        end
        model.record('Console','> '..command,'info')
        if ok and (command=='help'or command=='list'or command:match('^help%s')or command:match('^list%s'))then
            for line in tostring(message or ''):gmatch('[^\n]+')do model.record('Console',line,'info')end
        else model.record('Console',message or (ok and 'Command completed'or 'Command failed'),ok and 'info'or 'error')end
        state.command_history[#state.command_history+1]=command;if #state.command_history>50 then table.remove(state.command_history,1)end
        state.history_index=#state.command_history+1;state.command_text='';state.replace_input=false;state.scroll=0;state.anchor=nil
        suggestions={};suggestion_text=nil;suggestion_ready=false
        return ok,message
    end
    local plain_characters={[186]=';',[187]='=',[188]=',',[189]='-',[190]='.',[191]='/',[192]='`',[219]='[',[220]='\\',[221]=']',[222]="'",[109]='-',[110]='.'}
    local shifted_characters={[186]=':',[187]='+',[188]='<',[189]='_',[190]='>',[191]='?',[192]='~',[219]='{',[220]='|',[221]='}',[222]='"'}
    local function character(code,shift)
        if code>=65 and code<=90 then local c=string.char(code);return shift and c or c:lower()end
        if code>=48 and code<=57 then return shift and (')!@#$%^&*('):sub(code-47,code-47)or string.char(code)end
        if code>=96 and code<=105 then return tostring(code-96)end
        if code==32 then return ' 'end
        return shift and shifted_characters[code]or plain_characters[code]
    end
    function self.filter(input,open,dt)
        if not open then self.release();return input end
        if model.active_surface~=token then
            model.active_surface=token;state.drag=nil;state.resize=nil
            if not focus_requested then state.input_focused=false;state.focused=false end
            held={};for key=8,255 do held[key]=input.down(key)end;repeats={}
            mouse_held=input.down(1)
        elseif toggle_key then
            local down=input.down(toggle_key)
            if down and not held[toggle_key]then
                state.visible=not shown();explicitly_open=state.visible;state.input_focused=state.visible;state.focused=state.visible
                state.suppress_input=state.visible;repeats={};suggestion_ready=false;release_drag()
            end
            held[toggle_key]=down
        end
        focus_requested=false
        local x,y;if input.mouse then x,y=input.mouse()end
        local down=input.down(1);local over=shown()and inside(x,y,bounds)
        if shown()and over and down and not mouse_held then
            state.focused=true
            for i=#hits,1,-1 do if inside(x,y,hits[i])then hits[i].click(x,y);break end end
        elseif down and not mouse_held then state.focused=false;state.input_focused=false end
        local dragging=shown()and (state.drag or state.resize)
        if not down then
            if state.drag and state.drag.owner==token and parent and bounds then
                local gap=18*(screen.scale or 1)
                local b=bounds;local side
                if math.abs(b.x+b.w-parent.x)<gap then side='left'
                elseif math.abs(b.x-(parent.x+parent.w))<gap then side='right'
                elseif math.abs(b.y+b.h-parent.y)<gap then side='bottom'end
                if side then self.dock(side)end
            end
            release_drag()
        elseif x and y and screen then
            if state.drag and state.drag.owner==token then
                state.dock='free';state.x=math.max(0,math.min(screen.w-bounds.w,x-state.drag.dx));state.y=math.max(0,math.min(screen.h-bounds.h,y-state.drag.dy))
            elseif state.resize and state.resize.owner==token then
                local r=state.resize;local l,t,b,right=r.left,r.top,r.bottom,r.right;local s=screen.scale
                if r.edge:find('w',1,true)then l=math.max(0,math.min(right-420*s,x))end
                if r.edge:find('e',1,true)then right=math.min(screen.w,math.max(l+420*s,x))end
                if r.edge:find('s',1,true)then b=math.max(0,math.min(t-200*s,y))end
                if r.edge:find('n',1,true)then t=math.min(screen.h,math.max(b+200*s,y))end
                state.x,state.y=l,b;state.width,state.height=(right-l)/s,(t-b)/s;state.dock='free'
            end
        end
        local editing=shown()and state.input_focused
        if editing and not editing_last then state.suppress_input=true end
        editing_last=editing
        local blocked={};if shown()and toggle_key then blocked[toggle_key]=true end
        if shown()and state.input_focused then
            refresh_suggestions();local shift,ctrl=input.down(16),input.down(17)
            if state.suppress_input then for code=8,255 do held[code]=input.down(code)end;repeats={};state.suppress_input=false end
            for code=8,255 do
                local pressed=input.down(code);blocked[code]=true
                local count=pressed and not held[code]and 1 or 0
                local repeatable=code==8 or code==38 or code==40 or (not ctrl and code~=toggle_key and character(code,shift)~=nil)
                if pressed and repeatable then
                    if not held[code]then repeats[code]={age=0,next=.4}
                    elseif repeats[code]then
                        local r=repeats[code];local elapsed=type(dt)=='number'and dt==dt and math.max(0,math.min(.1,dt))or 0;r.age=r.age+elapsed
                        while r.age>=r.next and count<4 do count=count+1;r.next=r.next+.04 end
                    end
                else repeats[code]=nil end
                for _=1,count do
                    if code==toggle_key then
                    elseif code==9 then complete()
                    elseif code==13 then if #suggestions>0 then complete()else self.submit()end
                    elseif code==27 then if #suggestions>0 then dismissed=true;suggestions={}else state.input_focused=false end
                    elseif ctrl and code==65 then state.replace_input=true
                    elseif code==46 then state.command_text='';state.replace_input=false
                    elseif code==8 then state.command_text=state.replace_input and ''or backspace(state.command_text);state.replace_input=false
                    elseif code==38 or code==40 then
                        if #suggestions>0 then selected=((selected-1+(code==38 and -1 or 1))%#suggestions)+1
                        else
                            state.history_index=math.max(1,math.min(#state.command_history+1,(state.history_index or #state.command_history+1)+(code==38 and -1 or 1)))
                            state.command_text=state.command_history[state.history_index]or ''
                        end
                    elseif not ctrl then
                        local c=character(code,shift)
                        if c then if state.replace_input then state.command_text='';state.replace_input=false end;if #state.command_text+#c<=1024 then state.command_text=state.command_text..c end end
                    end
                end
                held[code]=pressed
            end
            refresh_suggestions()
        elseif shown()and state.focused then
            repeats={}
            local changes={[38]=1,[40]=-1,[33]=visible,[34]=-visible}
            for _,key in ipairs({38,40,33,34,36,35})do
                local pressed=input.down(key);blocked[key]=true
                if pressed and not held[key]then if key==36 then scroll(0,math.max(0,#lines-visible))elseif key==35 then scroll(0,0)else scroll(changes[key])end end
                held[key]=pressed
            end
        else repeats={} end
        if shown()and over and input.wheel then scroll(input.wheel()/120*3)end
        mouse_held=down
        local result={}
        for k,v in pairs(input)do result[k]=v end
        result.down=function(key)if blocked[key]then return false end;return input.down(key)end
        if over or dragging then result.mouse=function()end;result.wheel=function()return 0 end end
        return result
    end
    function self.dock(side)
        if side=='free'then state.dock='free';return true end
        if not parent or not bounds or not screen then return false,'Parent geometry unavailable'end
        local x,y=parent.x,parent.y
        if side=='left'then x=parent.x-bounds.w
        elseif side=='right'then x=parent.x+parent.w
        elseif side=='bottom'then y=parent.y-bounds.h
        else return false,'Unknown docking side'end
        if x<0 or y<0 or x+bounds.w>screen.w or y+bounds.h>screen.h then return false,'Not enough space beside parent'end
        state.dock=side;state.x,state.y=x,y;return true
    end
    function self.compose(w,h,parent_bounds,open)
        parent=parent_bounds;screen={w=w,h=h,scale=math.min(w/1920,h/1080)}
        if not open or not shown()then hits={};bounds=nil;self.bounds=nil;return {}end
        local s=screen.scale;local ww=math.max(420,math.min(w/s,state.width));local wh=math.max(200,math.min(h/s,state.height))
        state.width,state.height=ww,wh
        local x=math.max(0,math.min(w-ww*s,state.x or (w-ww*s)/2));local y=math.max(0,math.min(h-wh*s,state.y or 12*s))
        bounds={x=x,y=y,w=ww*s,h=wh*s};self.bounds=bounds
        if state.dock~='free'then local ok=self.dock(state.dock);if ok then x,y=state.x,state.y;bounds.x,bounds.y=x,y else state.dock='free'end end
        state.x,state.y=x,y;visible=math.max(1,math.floor((wh-122)/18));hits={}
        local width=math.max(12,math.floor((ww-30)/(14*.62)))
        if cached_revision~=model.revision or cached_width~=width then
            lines={};local next_cache={}
            for _,event in ipairs(model.read())do
                local signature=event.repeats..'/'..event.time..'/'..width
                local entry=cache[event.seq]
                if not entry or entry.signature~=signature then
                    local value=event.time..' '..event.severity:upper()..' '..event.source..': '..event.message..(event.repeats>1 and (' (x'..event.repeats..')')or '')
                    if event.details~=''then value=value..'\n  '..event.details end
                    if event.log_path~=''then value=value..'\n  Log: '..event.log_path end
                    entry={signature=signature,lines=wrap(value,width)}
                end
                next_cache[event.seq]=entry
                for index,line in ipairs(entry.lines)do lines[#lines+1]={text=line,severity=event.severity,seq=event.seq,line=index}end
            end
            cache=next_cache;cached_revision=model.revision;cached_width=width
            if state.anchor then for index,item in ipairs(lines)do if item.seq==state.anchor.seq and item.line==state.anchor.line then state.scroll=math.max(0,#lines-visible-index+1);break end end end
        end
        state.scroll=math.floor(math.max(0,math.min(math.max(0,#lines-visible),state.scroll)))
        local first_line=math.max(1,#lines-visible-state.scroll+1);local anchor=lines[first_line]
        state.anchor=state.scroll>0 and anchor and {seq=anchor.seq,line=anchor.line}or nil
        local commands={}
        local function rect(rx,ry,rw,rh,color,layer)commands[#commands+1]={type='rect',x=x+rx*s,y=y+ry*s,w=rw*s,h=rh*s,c=color,a=1,popup=true,layer=layer or 400,diagnostic_console=true}end
        local function text(rx,ry,value,color,size,layer)commands[#commands+1]={type='text',x=x+rx*s,y=y+ry*s,text=value,size=(size or 14)*s,c=color or palette.white,a=1,popup=true,layer=layer or 400,diagnostic_console=true}end
        local function hit(rx,ry,rw,rh,fn)hits[#hits+1]={x=x+rx*s,y=y+ry*s,w=rw*s,h=rh*s,click=fn}end
        rect(0,0,ww,wh,palette.background);rect(0,wh-34,ww,34,palette.header);text(12,wh-23,'MCM CONSOLE',palette.brass,17)
        hit(0,wh-34,ww,34,function(mx,my)state.drag={owner=token,dx=mx-x,dy=my-y}end)
        for index,side in ipairs({'free','left','right','bottom'})do
            local bx=ww-240+(index-1)*50
            text(bx,wh-22,side:upper(),state.dock==side and palette.focus or palette.white,12)
            hit(bx-3,wh-30,48,26,function()local ok,why=self.dock(side);self.notice=ok and ''or why end)
        end
        text(ww-27,wh-23,'X',palette.white,17);hit(ww-35,wh-32,30,28,function()explicitly_open=false;state.visible=false;state.input_focused=false;state.focused=false;release_drag()end)
        for index=first_line,math.min(#lines,first_line+visible-1)do local item=lines[index];text(12,wh-55-(index-first_line)*18,item.text,colors[item.severity])end
        if #lines==0 then text(12,wh-55,'No diagnostics events recorded yet.',colors.debug)end
        text(12,12,self.notice and self.notice~=''and self.notice or ((toggle_key==192 and '`'or toggle_key and 'VK '..toggle_key or 'Console')..' toggles | '..(state.scroll==0 and 'Following latest' or 'History paused')..' | retained '..model.count..'/'..model.capacity),palette.muted,12)
        if #lines>visible then
            local track=wh-120;local thumb=math.max(16,track*visible/#lines);local maximum=#lines-visible
            local offset=track-thumb;rect(ww-10,72,4,track,palette.line);rect(ww-12,72+offset*state.scroll/maximum,8,thumb,palette.focus)
            hit(ww-16,72,16,track,function(_,my)scroll(0,math.floor(math.max(0,math.min(1,(my-y-72*s)/(track*s)))*maximum))end)
        end
        rect(30,28,ww-105,32,palette.field)
        if state.input_focused then rect(30,28,2,32,palette.focus)end
        local command_tail=tail(state.command_text,math.max(1,math.floor((ww-125)/(14*.62))))
        text(12,38,'>',palette.brass,14)
        text(40,38,command_tail==''and not state.input_focused and 'help | namespace.field = value'or command_tail..(state.input_focused and '|'or ''),palette.white,14)
        hit(30,28,ww-105,32,function()self.focus()end)
        rect(ww-68,28,54,32,palette.field_hover);text(ww-62,38,'RUN',palette.brass,13)
        hit(ww-68,28,54,32,function()self.submit();self.focus()end)
        refresh_suggestions()
        if #suggestions>0 then
            local count=math.min(8,#suggestions,math.max(1,math.floor((wh-124)/24)))
            local first=math.max(1,math.min(selected-count+1,#suggestions-count+1))
            rect(30,64,ww-105,count*24+24,palette.header,412)
            for row=1,count do
                local index=first+row-1;local item=suggestions[index];local ry=64+(count-row)*24+24
                if index==selected then rect(32,ry,ww-109,24,palette.selected,413)end
                text(40,ry+6,prefix(item.label,math.max(1,math.floor((ww-133)/(13*.62)))),index==selected and palette.brass or palette.white,13,414)
                hit(32,ry,ww-109,24,function()complete(index)end)
            end
            text(40,70,'Tab / Enter complete | Up/Down select | Esc dismiss',palette.muted,12,414)
        end
        local function resize(edge,rx,ry,rw,rh)
            hit(rx,ry,rw,rh,function()state.drag=nil;state.resize={owner=token,edge=edge,left=x,right=x+ww*s,bottom=y,top=y+wh*s}end)
        end
        resize('w',0,12,5,wh-24);resize('e',ww-5,12,5,wh-24);resize('s',12,0,ww-24,5);resize('n',12,wh-5,ww-24,5)
        for _,corner in ipairs({{'sw',0,0},{'se',ww-12,0},{'nw',0,wh-12},{'ne',ww-12,wh-12}})do resize(corner[1],corner[2],corner[3],12,12);rect(corner[2]+3,corner[3]+3,5,5,palette.focus)end
        return commands
    end
    return self
end
return M
