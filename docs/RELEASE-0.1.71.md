# MCM 0.1.71 - open-menu performance

- Compare retained primitives directly instead of building hundreds of string signatures every frame. Preserve stale-ID destruction ordering and in-place color/geometry invalidation.
- Cache grouped mod catalogue by registry revision. Registrations, commits, mounts, removals and native-binding readout changes invalidate it; unchanged state reuses the catalogue.
- Stop scanning the keyboard for the hidden console. Drain held keys on editing transitions and share native key reads within each UI tick.
- Automatically detect HUD+ 0.2.9 and expose its 37 public controls; retain 0.2.8 and legacy compatibility without bundling HUD+ code or artwork.
- Support extended MBM registration display, preserve native key editing, split DBF Appearance settings into their own page, and validate menu ownership handoffs.
- Correct the API/menu version to 0.1.71.

## Local validation

Rendering, 43 core/UI contracts, DBF Appearance, menu takeover, 12 native-binding lookup contracts, 30 native binding transactions, 6 hosted-console contracts and 14 console command/logger contracts passed.

Deployed through LLL with existing settings/native helper preserved and changed Lua files byte-verified. Supported LLL cleanup/reload succeeded; 0.1.71 was also verified after normal restart before the final input adjustment.

Live instrumented open-menu samples: original 4.784 ms average / 12.043 ms worst per MCM update; final 2.001 ms average / 5.023 ms worst over 2,630 frames. Drawing fell from 3.065 ms to 0.428 ms. Follow-up sample: 1.880 ms average / 6.984 ms worst over 2,596 frames. These measure MCM Lua/update work, not total engine frame time or an FPS guarantee. Page and open/close transitions were requested during follow-up but were not independently counted; visual interaction acceptance remains with the user.

Evidence: dist/open-menu-performance. Profiling wrappers automatically restore after 25 seconds and were confirmed stopped. BSL is the main package. MDL/LLL share the optional package; install one MCM provider. Existing settings are retained.
