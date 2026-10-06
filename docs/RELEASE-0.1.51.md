# Preview 0.1.51

The loose Preview/LLL and Shared Loader Standalone packages contain the same current MCM Lua implementation and unchanged native input helper. Standalone retains its established Addon paths and manager GUID. LLL adds an installation guide to the loose package.

Changes: retain menu/navigation on focus loss while releasing capture; suppress held external input on return; preserve resize and numeric legacy controls; support authoritative linked settings, per-mod storage and display-only swatches; expose focused-page/binding status. Release metadata and documentation are refreshed. The standalone builder includes a local archive writer.

## Validation

All 11 focused LuaJIT suites pass: capture recovery, diagnostics, focus lifecycle, grouping navigation, loader handoff recovery, numeric legacy groups, linked controls, manager handoff, preview shader, storage provider and window resizing. Native input-policy/held-release checks and PowerShell deployment guards pass without attaching to the game.

The broad legacy suite passes its first 11 cases, then fails `keyboard edits selected settings, defaults and key capture` at `tests/contracts.lua:65` (initial Enter/toggle/default expectation). The callback fixture now checks the isolated callback error explicitly instead of assuming successful commits never log. Remaining broad-suite cases are not claimed passing.

Package verification covers Lua compilation, ZIP integrity, standalone archive round-trip/startup payload, matching runtime/DLL bytes, versions and hashes. Build receipts and SHA256SUMS are local dist outputs.

David confirmed the currently running MCM works before source push. That is user-reported live confirmation, not an independent clean-install test of each new archive. Runtime changes were preserved; this packaging pass changes version/author metadata only. Intermittent dropdown text loss remains under investigation.

## Live checks before publication

1. Install one provider with settings retained; start normally and confirm F10 opens one MCM.
2. Test third-party pages, toggles, dropdown text, numeric sliders, colors, linked values and persistence.
3. Move/resize, close/reopen and verify normal gameplay input returns.
4. Alt-Tab while open: background apps receive input, the menu stays open, held keys/clicks do not replay on return.
5. Test loader-manager handoff, disable/re-enable and shutdown restoration. Restart for native updates.
6. Test optional HUD preview with its separately installed assets.

No deployment, game restart or release upload is performed by this packaging work.
