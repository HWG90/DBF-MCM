# Preview 0.1.69

- Automatic HUD+ 0.2.8 owner integration: 33 public controls, owner validation and persistence, no local bridge patch required. HUD+ 0.2.2 compatibility is retained.
- Display extended MBM registrations while retaining API 1 version 3+ compatibility. Extended bindings remain read-only in MCM.
- Group Diver's Best Friend radial appearance settings on their own Appearance page while preserving saved IDs and callbacks.
- Add explicit menu ownership handoff with validation and prior-owner retirement.

Owner discovery is cached while runtime identity is unchanged. Offline coverage includes 10,000 unchanged polls with one HUD+ discovery scan, persistence failures, owner changes, native bindings and menu lifecycle regressions. Live runtime timing and transition verification remain pending.

Install one MCM instance and restart. BSL is the main package; MDL/LLL share the optional package. Existing settings are retained.
