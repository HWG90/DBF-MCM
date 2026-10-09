# MCM installation paths

## Live Lua Loader (LLL): loose package

[Live Lua Loader](https://github.com/HWG90/LLL) provides a context-adapter lifecycle compatible with MCM. Its authoritative [R18 mod guide](https://github.com/HWG90/LLL/blob/main/docs/MOD-MIGRATION.md) documents folder discovery, the API 2 context subset and cleanup polling.

1. Install LLL following its [release instructions](https://github.com/HWG90/LLL/releases). Use one startup/shared loader; avoid competing loader archives.
2. Disable the old MCM instance and remove/disable its startup archive before switching. LLL also scans MDL/Bingus folders, so avoid duplicate enabled copies.
3. Download **ModConfigurationMenu-Preview-0.1.54.zip** from [MCM prereleases](https://github.com/HWG90/DBF-MCM/releases). Extract its `dbf_mcm` folder to `%LOCALAPPDATA%/LLL/Helldivers2/Mods`.
4. Keep `mod.lua`, `library.txt` and the manifest-named `mcm_input_*.dll` in that folder. Install the complete folder; a lone Lua file cannot load the native capture helper.
5. Enable `live/dbf_mcm` through LLL if necessary, then press the configured key (DEL by default). Check LLL's logs for loading errors and test normal close, focus loss and input restoration.

MDL is not required on this path. MCM uses only the supported context subset; this is not a claim that LLL supports every MDL mod. MCM values remain in `%LOCALAPPDATA%/MDL/Helldivers2/Mods/dbf_mcm/settings` to preserve existing settings even when MDL is absent. LLL owns its separate lifecycle settings and logs.

LLL live reload replaces Lua lifecycle code. It does not unload/reload an already loaded native DLL, rebuild fonts/materials, or deploy compiled game archives. Native helper updates need a normal restart; game assets need their usual mod-manager deployment and restart. The adapter supports this route; a clean exact 0.1.54 installation remains unverified.

## Bingus Shared Loader: standalone archive

Requires Bingus Shared Loader. MDL and Bingus Mod Options Menu are not required for this variant.

1. Disable the MCM instance in MDL before deploying this package. Run only one MCM instance.
2. Import the Standalone ZIP into Arsenal, enable it alongside Shared Loader, deploy and restart.
3. Press the configured key (DEL by default). Verify menu input, close/reopen, Appearance preview, settings persistence and third-party pages.

The native input library is bundled inside the startup entry and extracted into `%LOCALAPPDATA%/DBF/MCM` on first launch. Settings currently use the same `%LOCALAPPDATA%/MDL/Helldivers2/Mods/dbf_mcm/settings` directory as the MDL variant to retain existing values; MDL does not have to be installed for that directory to work. Startup logs are in `%LOCALAPPDATA%/DBF/MCM/MCM-startup.log`.

The existing MDL ZIP remains an optional alternative for live reload. Startup compilation and archive checks do not prove live loading or input behavior. This standalone variant still needs the live installation test above.
