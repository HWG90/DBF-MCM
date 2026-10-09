# Credits

- **Goose** — DBF-MCM framework and native input helper.
- **CowboyBingus** — Bingus Shared Loader and Mod Options Menu compatibility ecosystem. Shared Loader is installed separately; Mod Options Menu assets are not bundled. Native helpers are credited below.
- **SkyUI contributors** and **Neanka / Fallout 4 MCM contributors** — inspiration for mod/page/control organization; their code and assets are not bundled. See [design references](MCM-REFERENCE.md).
- **Arrowhead Game Studios / Stingray** — game-provided GUI, fonts and runtime resources. No game binaries or stock assets are redistributed in these packages.

The standalone archive writer is the original bounded DBF-suite implementation, included locally for reproducible packaging. The input DLL is built from this repository's native source. Optional HUD preview materials belong to the separately installed HUD package.

- Native Escape-tab integration derives from [CowboyBingus Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu). Its memory/runtime helpers are included under [Zero-Clause BSD](../src/native_ui/LICENSE).
- The guarded Escape close request follows [CowboyBingus Better Lobby Management](https://github.com/CowboyBingus/BetterLobbyManagement/blob/f83aeacb4e1ade26943bd4ef85e1ee45d4c7b82b/src/menu.lua#L440-L452).
- HUD+ 0.2.2 retains its own code, assets, settings and native apply methods; local metadata/patch tools operate on the user-provided package and do not redistribute its runtime.
