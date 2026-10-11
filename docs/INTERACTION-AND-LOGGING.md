# Interaction and diagnostics

Tab accepts the active text field, dropdown or color dialog. With no active editor, it applies pending changes on the selected page. Otherwise it moves between navigation and settings. Shift+Tab moves focus while leaving page changes pending. Escape cancels the active popup or editor before closing MCM. The configured open/close shortcut remains available outside editors.

Right-click a setting for its edit/toggle/action, default reset and page Apply/Discard options. Default reset follows the same confirmation policy as an ordinary edit. Navigation menus open pages and expand/collapse mods, categories or sections. Opening or hovering a context menu never changes saved values. Disabled and retired owners cannot run stale actions.

The console opens with the backtick key inside MCM. Click its command field to type. Suggestions come from the active typed command service: LLL's command bus when available, or the installed MCM command provider. Tab completes without running a command. Up/Down selects a suggestion; Enter accepts it, then a second Enter runs the completed command. Escape dismisses suggestions before leaving the command field. The console does not evaluate Lua.

MCM reports registration and callback exceptions under the owning mod ID, including linked controls. Individual files use `MCM-<mod-id>.log` under the loader's log directory. Invalid path IDs are refused; a failed file sink falls back to the existing loader log. Logging failures do not change callback or persistence behavior.

LLL config supports `verbose_registration: false` by default. The exposed `mcm.verbose_registration` boolean can change it through the loader config setter. `DBFMCM.set_verbose(boolean)` changes the current runtime only; `get_verbose()` reads its state. Verbose registration reports page/category/control counts. Existing UI settings remain separate.

Shared loader diagnostics already include errors caught by that loader. Known additional mod log paths can be followed from their current end, with bounded reads and source attribution. Only provided files and reported errors are observable; MCM cannot intercept foreign native crashes or undisclosed log files.
