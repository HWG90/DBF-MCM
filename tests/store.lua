-- Regression for https://github.com/HWG90/DBF-MCM/issues/1.
-- Run from the repository root: lua5.1 tests/store.lua (or luajit).
local source=assert(io.open('src/store.lua','rb'))
local body=source:read('*a');source:close()
local factories={
    {'LLL module',assert(loadfile('src/store.lua'))()},
    {'MDL/Shared Loader bundle',assert(loadstring('local MCM={};MCM.store=(function()\n'..body..'\nend)();return MCM.store'))()},
}
local function same(actual,expected)
    for key,value in pairs(expected)do assert(actual[key]==value,'Unexpected value for '..key)end
    for key in pairs(actual)do assert(expected[key]~=nil,'Unexpected key '..key)end
end
for _,entry in ipairs(factories)do
    local filename=os.tmpname();os.remove(filename)
    local folder,id=filename:match('^(.*)[/\\]([^/\\]+)$')
    assert(folder and id and id:match('^[%w_-]+$'),'Unsupported temporary path')
    local target=folder..'/'..id..'.ini'
    local store=entry[2].new(folder)
    local function write(data)
        local f=assert(io.open(target,'wb'));assert(f:write(data));assert(f:close())
    end
    local function read()
        local f=assert(io.open(target,'rb'));local data=f:read('*a');f:close();return data
    end
    local ok,err=pcall(function()
        same(store.load(id),{}) -- Missing files use defaults and are not created.
        assert(io.open(target,'rb')==nil)
        write('');same(store.load(id),{});assert(read()=='')
        local malformed='garbage\nempty=\nbool=TRUE\ntext=unsafe text\ncolor=#zzzzzz\nhuge=1e12\ncode=os.execute("exit")\n'
        write(malformed);same(store.load(id),{});assert(read()==malformed)
        local valid={enabled=true,disabled=false,number=-12.5,color='#AABBCC',choice='Choice 1'}
        local mixed=malformed..'enabled=true\r\ndisabled=false\nnumber=-12.5\ncolor=#aabbcc\nchoice=@Choice 1\n'
        write(mixed);same(store.load(id),valid);assert(read()==mixed)
        write(string.rep(' ',65536-13)..'enabled=true\n')
        assert(#read()==65536);same(store.load(id),{enabled=true})
        write(read()..' ');same(store.load(id),{}) -- Existing size limit.
        assert(store.save(id,valid));same(store.load(id),valid)
        assert(store.save(id,{}));assert(read()=='');same(store.load(id),{})
        local Core=dofile('src/core.lua')
        local h=Core.new(store).register({id=id,name='Empty config',pages={{id='p',name='P',controls={{id='enabled',type='toggle',label='Enabled',default=true}}}}})
        assert(h.get('enabled')==true,'Empty file must retain registration defaults')
        assert(read()=='','Loading must not rewrite empty settings')
    end)
    os.remove(target);os.remove(target..'.tmp');os.remove(target..'.bak')
    assert(ok,err)
    print('PASS store: '..entry[1]..' empty/missing/malformed, values, limits, save/reload and registration')
end
