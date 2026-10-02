"""Run isolated LuaJIT contracts; does not attach to or launch the game."""
import ctypes,os
from pathlib import Path
root=Path(__file__).resolve().parents[1];os.chdir(root);(root/'tests/tmp').mkdir(exist_ok=True)
dll=ctypes.CDLL(r'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\bin\lua51.dll')
dll.luaL_newstate.restype=ctypes.c_void_p;state=dll.luaL_newstate()
dll.luaL_openlibs.argtypes=[ctypes.c_void_p];dll.luaL_openlibs(state)
dll.luaL_loadfile.argtypes=[ctypes.c_void_p,ctypes.c_char_p];dll.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
dll.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];dll.lua_tolstring.restype=ctypes.c_char_p
status=dll.luaL_loadfile(state,b'tests/contracts.lua') or dll.lua_pcall(state,0,0,0)
if status:print(dll.lua_tolstring(state,-1,None).decode(errors='replace'))
dll.lua_close.argtypes=[ctypes.c_void_p];dll.lua_close(state);raise SystemExit(status)
