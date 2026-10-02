# Shared Loader startup preview

Requires Bingus Shared Loader. MDL and Bingus Mod Options Menu are not required for this variant.

1. Disable the MCM instance in MDL before deploying this package. Run only one MCM instance.
2. Import the Standalone ZIP into Arsenal, enable it alongside Shared Loader, deploy and restart.
3. Press F10. Verify menu input, close/reopen, Appearance preview, settings persistence and third-party pages.

The native input library is bundled inside the startup entry and extracted into `%LOCALAPPDATA%/DBF/MCM` on first launch. Settings currently use the same `%LOCALAPPDATA%/MDL/Helldivers2/Mods/dbf_mcm/settings` directory as the MDL variant to retain existing values; MDL does not have to be installed for that directory to work. Startup logs are in `%LOCALAPPDATA%/DBF/MCM/MCM-startup.log`.

The existing MDL ZIP remains an optional alternative for live reload. Startup compilation and archive checks do not prove live loading or input behavior. This standalone variant still needs the live installation test above.
