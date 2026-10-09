-- Injected launchers only: this suite never opens a real browser.
local Platform=dofile('src/platform.lua')
local URL='https://github.com/HWG90/DBF-MCM'
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end

test('launcher construction performs no FFI or browser calls',function()
    local calls=0
    local ffi={load=function()calls=calls+1;error('unexpected load')end,cdef=function()calls=calls+1;error('unexpected definition')end}
    assert(type(Platform.windows_launcher(ffi))=='function'and calls==0)
end)

test('failed or incomplete restoration never launches a browser',function()
    local launches=0
    local launch=function()launches=launches+1;return 33 end
    local ok,reason=Platform.open_github(function()return false,'cursor restore pending'end,launch)
    assert(not ok and reason:find('cursor restore pending',1,true)and launches==0)
    ok,reason=Platform.open_github(function()return nil end,launch)
    assert(not ok and launches==0)
    ok,reason=Platform.open_github(function()error('restore failure')end,launch)
    assert(not ok and reason:find('restore failure',1,true)and launches==0)
end)

test('restoration succeeds before launching the fixed GitHub destination',function()
    local restored=false;local sequence={}
    Platform.github_url='https://example.invalid'
    local ok,reason=Platform.open_github(function()
        sequence[#sequence+1]='close';restored=true;return true
    end,function(url)
        sequence[#sequence+1]='launch';assert(restored and url==URL);return 33
    end)
    Platform.github_url=URL
    assert(ok and reason=='Opened GitHub'and table.concat(sequence,',')=='close,launch')
end)

test('ShellExecute failure and launcher exceptions are reported',function()
    for _,status in ipairs({0,32,'33',false,0/0})do
        local ok,reason=Platform.open_github(function()return true end,function()return status end)
        assert(not ok and reason:find('Could not open GitHub',1,true))
    end
    local ok,reason=Platform.open_github(function()return true end,function()return nil end)
    assert(not ok and reason:find('Windows status nil',1,true))
    ok,reason=Platform.open_github(function()return true end,function()error('no shell')end)
    assert(not ok and reason:find('no shell',1,true))
end)

test('Windows launcher lazily binds ShellExecuteW with safe UTF16 arguments',function()
    local loads,definitions,launches=0,0,0
    local shell=setmetatable({},{__index=function()error('undefined alias')end})
    local function narrow(value)
        local result={};local index=0
        while value[index]~=0 do assert(value[index]>0 and value[index]<128);result[#result+1]=string.char(value[index]);index=index+1 end
        return table.concat(result)
    end
    local ffi={load=function(name)assert(name=='shell32');loads=loads+1;return shell end,
        cdef=function(definition)
            definitions=definitions+1
            assert(definition:find('dbfmcm_open_github',1,true)and definition:find('ShellExecuteW',1,true))
            shell.dbfmcm_open_github=function(window,verb,url,parameters,cwd,show)
                launches=launches+1
                assert(window==nil and narrow(verb)=='open'and narrow(url)==URL and parameters==nil and cwd==nil and show==1)
                return 77
            end
        end,
        new=function(kind,size)assert(kind=='uint16_t[?]');local value={};for index=0,size-1 do value[index]=0 end;return value end,
        cast=function(kind,value)assert(kind=='intptr_t');return value end}
    local launch=Platform.windows_launcher(ffi)
    assert(loads==0 and definitions==0 and launches==0)
    assert(not pcall(launch,'https://example.invalid')and loads==0)
    assert(launch(URL)==77 and loads==1 and definitions==1 and launches==1)
    assert(launch(URL)==77 and loads==2 and definitions==1 and launches==2,'existing declaration was defined twice')
end)

print('PASS '..count..' browser-action contracts without a real browser launch')
