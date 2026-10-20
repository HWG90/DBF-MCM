# MCM 0.1.72 - conditional controls hotfix

- Fix the DBF Randomize input delay crash: its fixed-delay slider disables immediately and rejects stale clicks or drags safely.
- Add enabled_if, disabled_if and visible_if functions with draft-aware getters, set_condition and explicit refresh. Apply and Discard refresh dependent controls; failed predicates disable or hide their control without closing MCM.
- Forward legacy registry invalidation to the main catalogue, preserving imported ownership and saved values. Conditions run on changes or explicit refresh, not idle frames.
- Replace Reset One and Reset Page with one Reset Page to Defaults button. Individual reset remains in the right-click menu. Page reset respects Apply/Discard and preserves keybindings.

BSL live testing confirmed by David. Conditional, stale-drag, legacy/mounted-cache, confirmation/discard, core/UI and package checks passed. Install one MCM provider and restart; existing settings are retained. BSL is the main download; MDL/LLL share the optional ZIP.
