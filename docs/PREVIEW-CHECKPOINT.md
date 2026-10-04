# Preview checkpoint: 0.1.49

This checkpoint synchronizes the installed MCM authoring/grouping framework, immediate controls, preview popout, text retention, input restoration and optional legacy compatibility. Shared Loader and MDL startup adapters remain separate; run one instance. Bingus Mod Options is optional.

The HUD preview accepts `preview_mapping` (nine panel-inverse coefficients) and `preview_role` (main_panel, main_effect, child_panel, child_effect). Mapped materials use distinct GUI instances per role so one panel cannot overwrite another's uniforms. The vectors are refreshed even when triangles are retained. All role GUIs are destroyed during release. This uses existing mapped static materials and does not require the optional animation archive.

Run `python tests/run.py --suite tests/preview_shader.lua` for role isolation, retained uniform updates and cleanup. `python native/build.py` builds the content-addressed helper and runs its input-policy/held-input-release tests without attaching to a game. Both passed for this checkpoint. The installed preview repair still needs visual confirmation after game launch.

The older broad keyboard suite stops at its Enter-navigation expectation after the current menu behavior changed. That historical suite has not been fully reconciled, and this checkpoint does not claim it passes. Optional animation and matching native package deployment are separate from the installed static preview repair.
