# HUD+ and Escape-menu integration

## HUD+ 0.2.8: automatic integration

Install the normal MCM package for your loader alongside HUD+ 0.2.8. No patched
HUD+ archive, sidecar generation, bridge ZIP or installer is required. MCM finds
the running HUD+ runtime, verifies its exact base 76-option schema, and exposes
the 33 public settings using HUD+'s own labels, categories, ranges and choices.
Private calibration entries are not exposed. HUD+ add-on entries remain owned
by their own menus; extra appended options do not invalidate the base schema.

Edits call the existing owner's begin/edit/commit methods. HUD+ retains its
normal configuration file and handles validation, concurrent file changes and
disk failures. Native HUD+ edit sessions must be closed or applied first to
avoid overwriting an unfinished edit. Native changes refresh MCM on its existing
bounded integration tick. Discovery is cached until the update-chain identity,
runtime program, settings owner or running state changes; unchanged state does
not rescan the closure graph. The UI is removed when the owner retires.

Verified package: SHA-256
`389a321ca5ed2f287b9dd7eecddbbccd6f8483ebe266f0c076ba3f0c44488eee`.
Offline contracts exercise the package's actual pure Settings and Runtime
modules. Live menu coexistence, cursor transitions and CPU timing remain to be
verified after the user installs the package. MCM does not replace HUD+'s update
callback or modify its native menu methods for this settings integration.

## Legacy HUD+ 0.2.2 bridge tooling

HUD+ 0.2.2 has 41 settings across three MCM pages. Changes call HUD+'s own begin/edit/save/apply path and retain `%APPDATA%/hd2_hud_widgets.cfg`. External changes refresh MCM. Close or apply a native HUD+ edit session before editing here.

Prepare the bridge from your installed HUD+ copy, with the game closed:

```powershell
python tools/hud_plus_verify.py --package-dir "<HUD+ folder>" --runtime
python tools/hud_plus_patch.py --package-dir "<HUD+ folder>" --output dist/HUD-Plus-MCM-local.zip
./tools/install_hud_plus_bridge.ps1 -PackageDirectory "<HUD+ folder>" -CandidateZip dist/HUD-Plus-MCM-local.zip
```

Use a physical Python installation rather than the Windows Store alias. The installer checks the exact original archive, backs it up, and patches the existing Arsenal package and its matching game archive. It preserves HUD+ assets, manifest, configuration and native owner. Start the game after installation. An updated HUD+ package requires an updated bridge; unknown versions are refused. Do not enable a second HUD+ copy.

The generated HUD+ ZIP is for your installation only. Public MCM packages contain the original adapter and patch tools, without HUD+'s runtime or assets. The owner-provided bridge works without a sidecar. Optional recovery from a verified Lua update chain uses `hud_plus_labels.tsv`, generated with `tools/hud_plus_verify.py --package-dir "<HUD+ folder>" --metadata dist/hud_plus_labels.tsv --runtime`, beside MCM's `mod.lua`; this recovery path was not found in the current live session.

MCM registers a native tab through the same guarded native tab/text path used by CowboyBingus's Mod Options Menu. It preserves existing tabs and masks their expected count only during the verified owner checks. Selecting MCM requests the game's normal Escape-menu close, waits for the native stack to close, then opens MCM with its own input capture. Closing MCM returns to gameplay. A native dialog or unapplied game settings prevents the handoff. Native pointers/calls are enabled only after matching executable/game hashes, function signatures and object bounds.

Escape dismissal uses the validated Main-presenter pending-close path documented by [CowboyBingus Better Lobby Management](https://github.com/CowboyBingus/BetterLobbyManagement/blob/f83aeacb4e1ade26943bd4ef85e1ee45d4c7b82b/src/menu.lua#L440-L452). MCM verifies both instruction sites, the live owned tab and presenter storage before requesting closure. It does not synthesize keyboard input.

CowboyBingus native memory/runtime helpers are used under Zero-Clause BSD; their license is included. Cursor/input DLL bytes are unchanged. Settings header sizing accounts for native kerning so the full **Settings** label remains visible.

Offline tests include HUD+'s actual pure Options and BootState code with simulated I/O/native apply, plus native tab/restore calls through injected memory/FFI. In-game acceptance of the new entry, close/reopen, tab coexistence and one reversible HUD+ setting is still pending.
