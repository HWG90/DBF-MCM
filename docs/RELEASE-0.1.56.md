# Preview 0.1.56

The first Nexus release brings together the UI polish pass, configurable Settings and corrected two-column scrolling.

- Open MCM with **DEL** by default, rebind it in **Settings**, or use the native **MCM** Escape-menu tab.
- Adjust window size, UI scale and font size. Apply and Discard are buttons.
- Expanded pages keep both columns visible while scrolling, including Epic LUT Settings.
- Fixed native tab discovery and cursor handoff alongside MODS and HUD+.
- Selecting MCM requests the game's normal Escape-menu close, then opens MCM after gameplay input returns.

Choose the MDL/LLL loose package or the Bingus Shared Loader Standalone package. LLL uses the MDL package; run one MCM instance. The mod author quick start and API reference are included.

HUD+ 0.2.2 support requires the local owner bridge described in `INTEGRATIONS.md`. The third-party HUD+ archive is not included.

Validation: source contracts and package integrity/compilation checks run offline. The native tab is user-confirmed visible and opening in LLL. The newest Escape-close handoff, clean startup for each loader and HUD+ setting edits still require live confirmation. Controller navigation is not supported; dropdown text loss remains under investigation.
