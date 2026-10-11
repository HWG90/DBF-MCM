# Preview 0.1.57

A UI polish pass by **Goose**, with clearer navigation and a console that shares LLL's systems.

- Main game font, sliding On/Off switches and hover-safe control layers.
- Brighter inactive sidebar entries; dropdowns without side selectors.
- Tighter spacing and clamped control positions as the window grows, with room for setting details. Authored multi-column pages keep their layout.
- Pixel yellow skull, header/footer hazard stripes and right-click setting actions.
- **Tab** accepts an edit or applies pending changes; **Shift+Tab** changes focus.
- Console starts closed. Typed suggestions support arrows and Tab completion; Enter executes. LLL supplies shared commands, diagnostics and log reading.
- Mod-owned error logs and opt-in `verbose_registration` diagnostics. Existing mod IDs, settings and legacy integration are retained.

Open with **DEL**, rebind it in **Settings**, or use the **MCM** Escape-menu tab. Apply and Discard remain buttons.

**Main download:** `DBF-MCM-Standalone-0.1.57.zip` for Bingus Shared Loader.
**Optional download:** `ModConfigurationMenu-Preview-0.1.57.zip` for MDL or LLL. It is one combined package; LLL does not need MDL. Run one MCM instance and restart after updating.

Main-font rendering and typed console behavior are confirmed in LLL. Source, interaction, logging and package checks run offline. The latest navigation/dropdown refinements still need a live replay after restart, and BSL/MDL need their own live validation. Controller navigation is not supported.

HUD+ 0.2.2 requires the local owner bridge documented in [integration setup](INTEGRATIONS.md); third-party HUD+ code and assets are not included.
