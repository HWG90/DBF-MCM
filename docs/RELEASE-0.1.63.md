# Preview 0.1.63

Right-click a key field and choose **Unbind key**. Cleared standard bindings show **Not bound** and respect Apply/Discard on confirmation pages.

MBM unbinding removes only the keyboard mapping, preserves mouse/controller inputs, and persists through MCM's guarded startup restoration. Rebinding after clearing and rollback on save failure have isolated regression coverage. Chords remain editable in the native MODS page.

Unbind behavior passed isolated tests; live unbinding and restart testing remain pending. Direct rebinding and restart persistence were previously confirmed in LLL for 0.1.62.

Thanks to **Muchacho** for helping troubleshoot keybinding lookup issues.

**Main:** `DBF-MCM-Standalone-0.1.63.zip` for BSL v15+.
**Optional:** `ModConfigurationMenu-Preview-0.1.63.zip` for MDL API 2 or LLL R30+.
