# MCM with LLL

**LLL R30+ uses the same `ModConfigurationMenu-Preview-0.1.57.zip` as MDL.** It does not require MDL. Extract the complete `dbf_mcm` folder into `%LOCALAPPDATA%/LLL/Helldivers2/Mods`, disable any older MCM provider and restart.

LLL loads `main.lua` and the declared `src` modules through `manifest.json`. MDL loads `mod.lua` from the same package. Keep both entries, `config/defaults.cfg`, `library.txt` and the native DLL intact. MCM remains restart-only because it owns native input and startup hooks.

## Saved values and console

MCM writes values to `%LOCALAPPDATA%/LLL/Helldivers2/Settings/dbf_mcm`. Existing MDL INI files are read as fallback; they are not overwritten by LLL. The `mcm.settings` console fields use the existing preference handle.

MCM shares LLL's command bus, diagnostics and registered log reader. Its console starts closed; open **Console** explicitly, or use grave/tilde while MCM is open. Arrows select suggestions, Tab completes and Enter executes. Accepted hosted log registrations are read by LLL once, with local following retained when registration is unavailable.

Set `verbose_registration` to `true` in the saved `config.cfg`, or use `mcm.verbose_registration = true` in the console, to log registration details. It is off by default. See [diagnostics](DIAGNOSTICS.md).

## Source build

`py -3 tools/build_lll.py --version 0.1.57 --output dist/releases/0.1.57-lll`

This produces the modular build for development. The public optional download combines it with the MDL bundle. Building does not deploy or activate MCM.
