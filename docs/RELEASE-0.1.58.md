# Preview 0.1.58

Native Mod Bindings Menu hotkeys now appear under each matching mod's **Keybindings** page, including **First Person > Toggle First Person**. The page reads the current native binding; use **Options > Mouse & Keyboard > MODS** to rebind. Existing actions, controller mappings and saved game bindings stay with their original owner.

Thanks to **Muchacho** for troubleshooting and testing keybinding lookup. His screenshot shows a native mapping being read, but its displayed F13 name was not verified. The 0.1.59 investigation found a mismatch between native key IDs and the naming API. First Person failing to activate remains unresolved pending a live input test.

Photo-mode integrations can read a native real-time clock while simulation is paused or their settings menu has focus. `DBFMCM.camera_input.now()` exposes monotonic seconds before capture, during camera/menu focus and after release. This lets photo effects keep animating without consuming movement input.

The shared input lease, solo pause checks, saved bindings and settings storage remain intact. No new native DLL is required by this Lua API addition. The 0.1.57 font, layout, dropdown, right-click and shared-console improvements are included.

**Main download:** `DBF-MCM-Standalone-0.1.58.zip` for Bingus Shared Loader v15+ / API 1.
**Optional download:** `ModConfigurationMenu-Preview-0.1.58.zip` for MDL API 2 or LLL R30+. MDL and LLL use the same complete `dbf_mcm` package; LLL does not require MDL. Run one MCM instance and restart after updating.

Clock behavior passed isolated camera-input fixtures without a lease, with menu focus and after release. Core contracts and release-package verification cover source parity, native-library identity, module inventories, archive integrity and Lua compilation. The clock source is installed alongside War Journalist 0.8.1 in LLL; installation identity and fixture checks do not establish visual behavior for every effect. BSL and MDL retain preview status and need their own live replay.

MCM does not pause gameplay. Consumers own their camera, renderer and pause lifecycle. Optional HUD+ integration still requires the separately installed owner bridge; its third-party assets are not included.
