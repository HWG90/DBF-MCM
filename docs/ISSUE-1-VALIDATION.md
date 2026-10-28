# Empty configuration startup fix

Fixes https://github.com/HWG90/DBF-MCM/issues/1.

Base: `a4c16ddef6a5c7505bfdd6022d1cdb619082b1d5` (main inspected October 28, 2026).

`src/store.lua` now normalizes a nil file read to an empty string before taking its length. Empty files return an empty settings table, allowing registration defaults to apply. Parsing, the 65,536-byte limit, save behavior, paths, LLL legacy fallback and custom providers are unchanged. Loading does not rewrite files.

Run from the repository root:

```
lua5.1 tests/store.lua
luajit tests/store.lua
```

The regression uses temporary files and removes them afterward. It covers missing and empty files, malformed values, mixed valid/invalid input, booleans/numbers/colors/choices, the exact size boundary and oversized files, save/reload (including saving an empty table), and registering controls with defaults after an empty read. Both module loading and the bundle wrapper used by MDL/Shared Loader are exercised. Both runtimes reproduce the nil-length error against the original source and pass against the correction.

All 49 pre-existing runnable Lua test files were executed separately under both runtimes, excluding `ui_preview_fixture.lua` (a fixture). Their exit statuses were compared against the unchanged base:

| Runtime | Existing suites passed | Existing suites failed | Changed exit statuses |
| --- | ---: | ---: | ---: |
| Lua 5.1 | 38 | 11 | 0 |
| LuaJIT | 40 | 9 | 0 |

The new storage suite also passes under both runtimes. `git diff --check` passes.

Existing failures on both runtimes: `console_host`, `contracts`, `focus_lifecycle`, `handoff_recovery`, `hud_plus_028`, `hud_plus_029`, `linked_controls`, `manager_handoff`, `native_memory_pointer`. These involve absent sibling LLL/HUD fixtures, an absent generated bundle, existing adapter/control assertions, and Windows native dependencies. Lua 5.1 additionally fails `native_binding_transactions` (missing `bit`) and `native_entry` (LuaJIT-specific stripped-debug fixture).

Loader compatibility was checked at source level: `tools/build_lll.py` copies the shared store as a module; `build.py` embeds it in `MCM.store`; `build_standalone.py` embeds that bundle in Shared Loader startup. The correction uses only Lua 5.1 syntax and does not touch those entry points. The repository's Python test runner requires a hard-coded Windows game DLL, so the installed Lua interpreters were used directly. Full release builds need the absent `native/build` DLL artifacts; no game startup or native Windows/loader runtime validation was performed.
