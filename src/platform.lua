-- External actions run only after menu input ownership has been restored.
local P={}
local URL='https://github.com/HWG90/DBF-MCM'
P.github_url=URL

function P.open_github(close,launch)
    local called,restored,reason=pcall(close)
    if not called then return false,'Could not restore menu input: '..tostring(restored)end
    if restored~=true then return false,'Restore menu input before opening GitHub'..(reason and (': '..tostring(reason))or '')end
    local launched,status=pcall(launch,URL)
    if not launched then return false,'Could not open GitHub: '..tostring(status)end
    if type(status)~='number' or not(status>32)then return false,'Could not open GitHub (Windows status '..tostring(status)..')'end
    return true,'Opened GitHub'
end

function P.windows_launcher(ffi)
    return function(url)
        assert(url==URL,'Unsupported browser destination')
        local shell=ffi.load('shell32')
        if not pcall(function()return shell.dbfmcm_open_github end)then
            ffi.cdef('void *dbfmcm_open_github(void *,const uint16_t *,const uint16_t *,const uint16_t *,const uint16_t *,int) __asm__("ShellExecuteW");')
        end
        local function wide(value)
            local result=ffi.new('uint16_t[?]',#value+1)
            for index=1,#value do result[index-1]=value:byte(index)end
            result[#value]=0
            return result
        end
        local result=shell.dbfmcm_open_github(nil,wide('open'),wide(URL),nil,nil,1)
        return tonumber(ffi.cast('intptr_t',result))
    end
end
return P
