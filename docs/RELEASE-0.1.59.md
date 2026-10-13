# Preview 0.1.59

Mod Bindings Menu entries now use compact action/key rows. Ship Station Hotkeys' verified native codes display **Tab, F1 and F5–F8**, with readable action names instead of registration IDs. MCM previously passed these game input IDs to a different key-name API, causing F1 to appear as Right Shift. Threshold hex values and other native internals are removed from the menu.

MBM pages identify their native owner and direct rebinding to **Options > Mouse & Keyboard > MODS**. They remain read-only; existing bindings, callbacks, controller mappings and ordinary MCM settings are preserved. Codes without a verified name display **Unknown keyboard key** rather than an incorrect name. Full custom-key name coverage and reported activation failures still need live verification.

Thanks to **Muchacho** for troubleshooting and testing native keybinding lookup.

**Main:** `DBF-MCM-Standalone-0.1.59.zip` for BSL v15+.
**Optional:** `ModConfigurationMenu-Preview-0.1.59.zip` for MDL API 2 or LLL R30+. MDL and LLL share one package.

The 0.1.58 camera-clock, font and shared-console changes are included. Updates take effect after a normal game restart; offline checks do not establish native shortcut activation.
