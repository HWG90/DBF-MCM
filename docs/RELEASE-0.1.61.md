# Preview 0.1.61

The MBM keyboard editor now updates both native encodings of a key. Previously MCM could display and save a new key while gameplay continued using the old one.

MCM also compares the complete mapping fingerprint when restoring saved shortcuts. Later native edits take priority, including changes to activation metadata that keep the same key. Existing mouse/controller mappings, activation type and threshold remain intact.

The direct Armory F2-to-F3 rebind was confirmed in LLL: F3 opens Armory with both menus closed. Isolated transaction and editor checks cover both key encodings, rollback and restart reconciliation. Restart persistence is still undergoing live verification; BSL/MDL live validation remains separate.

Thanks to **Muchacho** for helping troubleshoot keybinding lookup.

**Main:** `DBF-MCM-Standalone-0.1.61.zip` for BSL v15+.
**Optional:** `ModConfigurationMenu-Preview-0.1.61.zip` for MDL API 2 or LLL R30+. Updates require a normal game restart.
