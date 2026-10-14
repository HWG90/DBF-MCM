# Install MCM 0.1.62

Use one MCM instance. Disable the old provider before switching loaders, and restart Helldivers after updating.

## Bingus Shared Loader — main download

1. Install **Bingus Shared Loader v15+ / API 1**.
2. Import **DBF-MCM-Standalone-0.1.62.zip** into Arsenal.
3. Enable MCM alongside Shared Loader, deploy and restart.
4. Open MCM with **DEL** or the **MCM** Escape-menu tab.

MDL and Bingus Mod Options Menu are not required. The native helper is bundled and extracted to `%LOCALAPPDATA%/DBF/MCM`. Startup logs are in `MCM-startup.log` there.

## LLL or MDL — the same optional download

Use **ModConfigurationMenu-Preview-0.1.62.zip**. Public downloads are listed on [Nexus](https://www.nexusmods.com/helldivers2/mods/17157), [Ayaka](https://ayakamods.com/mods/dbf-mod-configuration-menu.4846/) and [GitHub](https://github.com/HWG90/DBF-MCM/releases); check the listed version before downloading.

| Loader | Extract `dbf_mcm` into |
| --- | --- |
| [LLL R30+](https://github.com/HWG90/LLL/releases) | `%LOCALAPPDATA%/LLL/Helldivers2/Mods` |
| MDL API 2 | `%LOCALAPPDATA%/MDL/Helldivers2/Mods` |

Copy the **whole folder**, including `main.lua`, `mod.lua`, `manifest.json`, `config`, `src`, `library.txt` and the named `mcm_input_*.dll`. LLL uses the modular entry; MDL uses the bundled entry. **LLL does not require MDL or a separate MCM download.**

Enable `live/dbf_mcm` in LLL if necessary, restart, then press **DEL**. LLL also discovers some other loader folders, so avoid duplicate enabled MCM copies.

## Settings and updates

- **LLL:** `%LOCALAPPDATA%/LLL/Helldivers2/Settings/dbf_mcm`. Existing MDL INI values are read as fallback when no LLL value file exists.
- **MDL/Shared Loader:** `%LOCALAPPDATA%/MDL/Helldivers2/Mods/dbf_mcm/settings`. MDL does not need to be installed for Shared Loader to use this folder.

Keep your settings when replacing the mod folder. LLL's `config.cfg` contains `verbose_registration` and loader-owned preferences; edit the saved config, not packaged defaults. Native helpers and MCM's startup hooks require a normal game restart.

After installation, check open/close, cursor restoration, saved settings and your third-party pages. Offline package checks do not prove every loader's live behavior.
