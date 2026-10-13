# Preview 0.1.60

Bind **Mod Bindings Menu** keyboard shortcuts directly in MCM: select the action, press Enter or click its key field, then press the new key. It saves immediately; Escape cancels.

Existing mods keep their original native action IDs and continue reading MBM. The editor changes only one simple keyboard mapping, preserving its activation type, threshold and every mouse/controller mapping. Multiple-key and chord mappings remain available through the game's native MODS page.

MCM stores keyboard edits by stable MBM binding ID in `mbm_bindings.ini` beside its other settings. On startup, an edit is restored only while the original native baseline still matches. Later changes through the native MODS page take priority. MCM does not edit the game's saved input file or replace MBM's activation reader.

Native writes check the supported game build, current input owner, current map vector and action identity; readback must match. A failed persistence write rolls the native record back. These checks and the capture editor have isolated regression coverage. Native F2/A/F1 key-code captures were observed; direct activation and restart persistence are still undergoing live verification.

Thanks to **Muchacho** for helping troubleshoot native keybinding lookup.

**Main:** `DBF-MCM-Standalone-0.1.60.zip` for BSL v15+.
**Optional:** `ModConfigurationMenu-Preview-0.1.60.zip` for MDL API 2 or LLL R30+. Updates require a normal game restart.
