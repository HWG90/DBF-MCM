# Preview 0.1.65

MCM now adds its own tab directly to the native Escape-menu row. It no longer searches through other mods' update callbacks to find a MODS-tab owner. Existing native labels, row capacity, tab ownership, cursor restoration and the Escape-to-MCM handoff remain checked. DEL still opens MCM directly.

Native Escape-menu polling runs once through MCM's adapter lifecycle, without a second global update wrapper.

In one live LLL session, MCM's closed-menu update cost fell from about 214 to 8 ms per second after removing discovery. Results vary with the active mods and menu state. Live logs confirmed native-tab registration and opening MCM after Escape closed.

Validation: 27 native-entry contracts, including direct insertion without discovery and the 100-frame single-poll check, plus 42 core menu contracts.

**Main:** BSL Standalone. **Optional:** combined MDL / LLL package. Install one instance and restart after updating. Existing settings are retained.
