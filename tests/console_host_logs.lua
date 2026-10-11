-- Host handoff contracts use the maintained LLL reader and injected file services.
local Console=assert(loadfile('src/console.lua'))()
local LLLReader=assert(loadfile('../DBF-Suite/LLL/src/log_reader.lua'))()
local passed=0
local function test(name,fn)local ok,why=pcall(fn);assert(ok,name..': '..tostring(why));passed=passed+1;print('PASS '..name)end
local function model()return Console.new({clock=function()return 0,'12:00:00'end})end
local function empty(value)return next(value)==nil end
local function readable(calls)
    return function(path,mode)
        calls.opens=(calls.opens or 0)+1;assert(mode=='rb')
        return {close=function()calls.closes=(calls.closes or 0)+1;return true end}
    end
end
local function host(diagnostics,fn,modules,catalog)
    return {diagnostics=diagnostics,register_log=fn,modules=modules or {},live_catalog=catalog or {}}
end

test('actual LLL registration removes fallback and records each appended error once',function()
    local diagnostics=model();local path='logs/Demo.log';local content='ERROR old session\n';local stamp=1
    local calls={reads=0,registers=0,opens=0,closes=0}
    local platform={log_directory='logs',stat=function(p)return p==path and tostring(stamp)or nil end,
        read_log=function(p,position,limit,changed)
            assert(p==path);calls.reads=calls.reads+1;local total=#content
            if position==nil then position=total elseif position<0 then position=math.max(0,total+position)elseif position>total then position=0 end
            local ending=math.min(total,position+limit);return content:sub(position+1,ending),ending,false,false,total
        end}
    local reader=LLLReader.new(platform,diagnostics,{own_log='logs/LiveLuaLoader.log'})
    local loader
    loader=host(diagnostics,function(source,p)
        calls.registers=calls.registers+1
        if type(source)~='string'or not loader.modules[source]then return false,'Unknown mod source'end
        return reader.register(source,p,nil,true)
    end,{['live/demo']='loaded'})
    local helper=Console.host_logs(diagnostics,{open=readable(calls)})
    local paths={demo=path,demo_alias=path};local keys={demo='live/demo',demo_alias='live/demo'}
    local fallback=helper.filter(paths,keys,loader)
    assert(empty(fallback)and calls.registers==1 and calls.opens==1 and calls.closes==1 and reader.count==1)
    local fallback_reader=Console.follow_logs(diagnostics,{paths=function()return fallback end,open=function()error('accepted host file must not be opened by fallback')end})
    reader.poll();assert(diagnostics.count==0,'handoff starts at EOF')
    content=content..'ERROR one new event\n';stamp=2;reader.poll();assert(fallback_reader.tick(.5)==0)
    local events=diagnostics.read();assert(#events==1 and events[1].source=='live/demo'and events[1].message=='ERROR one new event'and events[1].log_path==path)
    fallback=helper.filter(paths,keys,loader);reader.poll();fallback_reader.tick(.5)
    assert(diagnostics.count==1 and calls.registers==1,'accepted file has a single reader and registration')
end)

test('only exact module or catalog keys are recognized without guessing owners',function()
    local diagnostics=model();local calls={registers=0};local loader=host(diagnostics,function()calls.registers=calls.registers+1;return true end,{['live/known']='loaded'},{['live/catalog_only']={}})
    local helper=Console.host_logs(diagnostics,{open=readable(calls)})
    local paths={unknown='logs/Unknown.log',numeric='logs/Numeric.log',synthetic='logs/Synthetic.log',missing='logs/Missing.log'}
    local fallback=helper.filter(paths,{unknown='known',numeric=1,synthetic='known__Log_1'},loader)
    for source,path in pairs(paths)do assert(fallback[source]==path)end
    assert(calls.registers==0 and not calls.opens)
    fallback=helper.filter({module='logs/Module.log',catalog='logs/Catalog.log'},{module='live/known',catalog='live/catalog_only'},loader)
    assert(empty(fallback)and calls.registers==2 and calls.opens==2)
end)

test('diagnostic identity mismatch retains fallback and invalidates cached acceptance',function()
    local diagnostics=model();local calls={registers=0};local loader=host(diagnostics,function()calls.registers=calls.registers+1;return true end,{['live/owner']=true})
    local helper=Console.host_logs(diagnostics,{open=readable(calls)});local paths={owner='logs/Owner.log'};local keys={owner='live/owner'}
    assert(empty(helper.filter(paths,keys,loader)))
    loader.diagnostics=model();assert(helper.filter(paths,keys,loader).owner==paths.owner and calls.registers==1)
    loader.diagnostics=diagnostics;assert(empty(helper.filter(paths,keys,loader))and calls.registers==2)
end)

test('unreadable or unsuccessfully closed files never register with the host',function()
    local diagnostics=model();local count=0;local loader=host(diagnostics,function()count=count+1;return true end,{['live/owner']=true})
    local paths,keys={owner='logs/Owner.log'},{owner='live/owner'}
    for _,open in ipairs({function()return nil,'unreadable'end,function()error('open exception')end,
        function()return {close=function()return false,'close failure'end}end,
        function()return {close=function()error('close exception')end}end,
        function()return {close=function()return nil,'close denied'end}end})do
        local helper=Console.host_logs(diagnostics,{open=open});assert(helper.filter(paths,keys,loader).owner==paths.owner)
    end
    assert(count==0)
end)

test('host registration false exceptions and nonboolean success preserve fallback',function()
    local diagnostics=model();local paths,keys={owner='logs/Owner.log'},{owner='live/owner'}
    for _,fn in ipairs({function()return false,'reader unavailable'end,function()error('host failed')end,function()return 'yes'end})do
        local helper=Console.host_logs(diagnostics,{open=readable({})});local loader=host(diagnostics,fn,{['live/owner']=true})
        assert(helper.filter(paths,keys,loader).owner==paths.owner)
    end
end)

test('successful paths cache case-insensitively and host or registration changes invalidate',function()
    local diagnostics=model();local calls={registers=0};local fn=function()calls.registers=calls.registers+1;return true end
    local loader=host(diagnostics,fn,{['live/owner']=true});local helper=Console.host_logs(diagnostics,{open=readable(calls)})
    assert(empty(helper.filter({owner='C:/Logs/Owner.log'},{owner='live/owner'},loader)))
    assert(empty(helper.filter({alias='c:\\logs\\OWNER.LOG'},{alias='live/owner'},loader))and calls.registers==1 and calls.opens==1)
    loader=host(diagnostics,fn,{['live/owner']=true})
    assert(empty(helper.filter({owner='C:/Logs/Owner.log'},{owner='live/owner'},loader))and calls.registers==2)
    loader.register_log=function()calls.registers=calls.registers+1;return true end
    assert(empty(helper.filter({owner='C:/Logs/Owner.log'},{owner='live/owner'},loader))and calls.registers==3)
    loader.modules['live/owner']=nil;local fallback=helper.filter({owner='C:/Logs/Owner.log'},{owner='live/owner'},loader)
    assert(fallback.owner=='C:/Logs/Owner.log'and calls.registers==3)
end)

test('cached handoff requires fresh exact ownership and cannot hide unknown or conflicting paths',function()
    local diagnostics=model();local called={};local path='logs/Changed.log'
    local loader=host(diagnostics,function(source)called[#called+1]=source;return true end,{['live/a']=true,['live/b']=true})
    local helper=Console.host_logs(diagnostics,{open=readable({})})
    assert(empty(helper.filter({row=path},{row='live/a'},loader))and called[1]=='live/a')
    assert(empty(helper.filter({row=path},{row='live/b'},loader))and #called==2 and called[2]=='live/b')
    assert(helper.filter({row=path},{},loader).row==path and #called==2,'Cached owner hid an unproven path')
    assert(empty(helper.filter({row=path},{row='live/a'},loader)))
    local fallback=helper.filter({a=path,b=path},{a='live/a',b='live/b'},loader)
    assert(fallback.a==path and fallback.b==path and #called==3,'Cached route swallowed conflicting ownership')
end)

test('conflicting exact owners leave a common file in fallback without registration',function()
    local diagnostics=model();local calls={registers=0};local loader=host(diagnostics,function()calls.registers=calls.registers+1;return true end,{['live/a']=true,['mdl/a']=true})
    local helper=Console.host_logs(diagnostics,{open=readable(calls)})
    local paths={a='logs/Common.log',b='LOGS/common.LOG'}
    local fallback=helper.filter(paths,{a='live/a',b='mdl/a'},loader)
    assert(fallback.a==paths.a and fallback.b==paths.b and calls.registers==0 and not calls.opens)
end)

test('max attempts rotates fairly across known files even when registrations fail',function()
    local diagnostics=model();local calls,seen={},{};local paths,keys,modules={},{},{}
    for index=1,7 do local source='owner'..index;paths[source]='logs/'..source..'.log';keys[source]='live/'..source;modules[keys[source]]=true end
    local loader=host(diagnostics,function(source)seen[source]=(seen[source]or 0)+1;return false,'retry later'end,modules)
    local helper=Console.host_logs(diagnostics,{open=readable(calls),max_attempts=2})
    for _=1,4 do local before=calls.opens or 0;local fallback=helper.filter(paths,keys,loader);assert(calls.opens-before<=2 and not empty(fallback))end
    for source in pairs(modules)do assert(seen[source],'known source starved: '..source)end
    assert(calls.opens==calls.closes)
end)
print('PASS '..passed..' console host log contracts')
