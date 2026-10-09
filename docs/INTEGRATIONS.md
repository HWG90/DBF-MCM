# HUD+ and Escape-menu integration

HUD+ 0.2.2 has 41 settings across three MCM pages. Changes call HUD+'s own begin/edit/save/apply path and retain `%APPDATA%/hd2_hud_widgets.cfg`. External changes refresh MCM. Close or apply a native HUD+ edit session before editing here.

Prepare the bridge from your installed HUD+ copy, with the game closed:

```powershell
python tools/hud_plus_verify.py --package-dir "<HUD+ folder>" --runtime
python tools/hud_plus_patch.py --package-dir "<HUD+ folder>" --output dist/HUD-Plus-MCM-local.zip
./tools/install_hud_plus_bridge.ps1 -PackageDirectory "<HUD+ folder>" -CandidateZip dist/HUD-Plus-MCM-local.zip
```

Use a physical Python installation rather than the Windows Store alias. The installer checks the exact original archive, backs it up, and patches the existing Arsenal package and its matching game archive. It preserves HUD+ assets, manifest, configuration and native owner. Start the game after installation. An updated HUD+ package requires an updated bridge; unknown versions are refused. Do not enable a second HUD+ copy.

The generated HUD+ ZIP is for your installation only. Public MCM packages contain the original adapter and patch tools, without HUD+'s runtime or assets. The owner-provided bridge works without a sidecar. Optional recovery from a verified Lua update chain uses `hud_plus_labels.tsv`, generated with `tools/hud_plus_verify.py --package-dir "<HUD+ folder>" --metadata dist/hud_plus_labels.tsv --runtime`, beside MCM's `mod.lua`; this recovery path was not found in the current live session.

MCM registers a native tab through the same guarded native tab/text path used by CowboyBingus's Mod Options Menu. It preserves existing tabs and masks their expected count only during the verified owner checks. The tab hosts MCM inside the native Escape menu and restores the prior panel/selection on close. A verified gameplay cursor baseline and foreground owner are required. Menu coverage or ownership loss defers restoration rather than taking another menu's input. Native pointers/calls are enabled only after matching executable/game hashes, function signatures and object bounds.

CowboyBingus native memory/runtime helpers are used under Zero-Clause BSD; their license is included. Cursor/input DLL bytes are unchanged. Settings header sizing accounts for native kerning so the full **Settings** label remains visible.

Offline tests include HUD+'s actual pure Options and BootState code with simulated I/O/native apply, plus native tab/restore calls through injected memory/FFI. In-game acceptance of the new entry, close/reopen, tab coexistence and one reversible HUD+ setting is still pending.
