# Physical Windows deployment

Build with `build.ps1 -Python <non-Store Python executable>`. The default locates the bundled workspace interpreter. Both Python builders reject Microsoft Store/WindowsApps runtimes before filesystem work; `build.py --install` is retired and fails with instructions.

Use `deploy.ps1 -Candidate <reviewed mod.lua>` for an existing LLL MCM installation. It replaces only Lua; it never installs a native input DLL. The candidate must retain resizing and numeric legacy-group handling. Do not deploy unrelated framework changes merely to install a batch setter.

Deployment checks absolute target containment, rejects Store/LocalCache paths, obtains the actual installed file path from its opened Win32 handle, backs up the exact baseline with a hash check, and verifies candidate versus real installed SHA-256 immediately and after a bounded reload wait. A missing success marker, redirected path, changed baseline or hash mismatch stops loudly; it does not keep overwriting the destination. Backups and receipts live under `dist/deployment-backups`.

Run `tests/deploy_guards.ps1` for rejection and protected-feature checks. These guard the supported entrypoints, not arbitrary external scripts. A direct external copy can still bypass them. MDL/first-install/native-library changes need their own reviewed deployment path.

Microsoft Store Python can resolve an apparent AppData path into its package LocalCache. A self-check through that same interpreter can verify the wrong file. Native PowerShell hash checks and final-handle-path checks are therefore independent of the build interpreter.
