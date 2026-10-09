-- UI colors and readable key labels.
local M={}
M.palette={background={17,22,27},panel={23,29,35},header={31,38,44},
    border={65,77,85},line={43,53,61},white={231,236,239},muted={153,166,175},
    brass={221,184,105},focus={119,185,205},hover={35,46,55},selected={38,53,63},
    field={29,39,47},field_hover={40,55,65},enabled={118,207,177},disabled={111,124,133}}
function M.key_name(code)
    local names={[8]='Backspace',[9]='Tab',[13]='Enter',[16]='Shift',[17]='Ctrl',[18]='Alt',[27]='Esc',[32]='Space',
        [33]='Page Up',[34]='Page Down',[35]='End',[36]='Home',[37]='Left',[38]='Up',[39]='Right',[40]='Down',[45]='Insert',[46]='Del'}
    if names[code]then return names[code]end
    if code>=48 and code<=90 then return string.char(code)end
    if code>=112 and code<=135 then return 'F'..tostring(code-111)end
    if code>=96 and code<=105 then return 'Num '..tostring(code-96)end
    return 'VK '..tostring(code)
end

return M
