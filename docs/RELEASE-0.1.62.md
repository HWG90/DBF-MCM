# Preview 0.1.62

Saved MBM shortcuts now wait for the native input profile during startup. The game can expose its shipped bindings before applying saved settings; MCM previously treated that temporary mismatch as a native edit and removed the override.

Restoration still requires the exact saved baseline. Later native-page edits remain authoritative, and unrelated mappings are preserved. The startup default-to-profile transition has an isolated regression test.

Direct rebinding and restart persistence were confirmed in LLL: Armory remained on F3 and opened after a normal restart. BSL/MDL live validation remains separate.

Thanks to **Muchacho** for helping troubleshoot keybindings.

**Main:** `DBF-MCM-Standalone-0.1.62.zip` for BSL v15+.
**Optional:** `ModConfigurationMenu-Preview-0.1.62.zip` for MDL API 2 or LLL R30+.
