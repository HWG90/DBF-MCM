# Preview 0.1.66

Improved native Escape-menu coexistence with Bingus Mod Options Menu and other update wrappers. Authenticated MODS callbacks receive their expected four-tab view while MCM retains its own tab in the full row.

Owner lookup now follows deeper update forwarding chains with bounded fallback, and failed discovery backs off for 60 frames instead of searching every frame. Provider replacement and cleanup preserve newer callback owners. Native-menu polling remains lifecycle driven.

Includes the earlier keyboard unbind/context-menu fixes. Existing settings and mouse/controller mappings are retained.

Validation includes native-entry, core menu and binding regression tests plus both loader packages. Live performance and compatibility results for this revision remain unverified.

**Main:** BSL Standalone. **Optional:** combined MDL / LLL ZIP. Install one MCM instance and restart after updating.

Thanks to **Muchacho** for helping troubleshoot keybinding lookup issues.
