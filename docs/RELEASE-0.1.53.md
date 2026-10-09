# Preview 0.1.53 — UI polish and Settings

- Clearer headings, roomier rows, subdued panels, distinct hover/focus/enabled states and readable key labels.
- Settings beside Mod Configuration: rebindable Open/Close (DEL default), preferred dimensions, UI scale, font size, window reset and GitHub browser action.
- Apply/Discard/Reset Setting are buttons. MCM assigns no extra Settings/Apply/Discard/default shortcuts.
- Keyboard dropdowns, draggable scrollbars, scoped UTF-8 label scrolling, mixed immediate/deferred settings and authoritative linked-control notices.
- Cursor readback safeguards and ownership restoration retained. Native DLL bytes are unchanged.
- Source split into controller, input, rendering, text and theme modules; install format remains a single bundled entry.
- Short [mod-author guide](AUTHOR-GUIDE.md) includes a tested registration example and function table.

## Packages

One loose Preview package serves MDL API 2 and LLL. Standalone serves Bingus Shared Loader v15+ / API 1. Use one MCM provider. Existing IDs, callbacks and settings paths remain stable.

## Validation

The broad suite has 42 passing contracts. Focused checks cover preferences, saved rebinding, invalid-key rejection, size/font scaling, button confirmation, browser restoration ordering, linked settings, hover/depth/cancellation, capture, focus return, loader handoff and preview cleanup. All source and both generated Lua entries compile; ZIPs and Standalone payloads pass integrity checks. Nine composed scenes matched exactly before/after the module extraction, prior to the subsequent shortcut simplification and spacing fixes.

Previews use the actual Lua draw commands with approximate fonts. Tests do not open a real browser, attach to the game or prove live appearance. Repeat live control, small/scaled window, focus loss, held-input suppression, handoff and restoration checks after loading.

## Remaining integration work

HUD+ 0.2.2 adds a native Options tab and keeps its settings singleton private; its supplied module returns only installation status. It provides no supported MCM registration/setter bridge or verified Escape-root button registration. HUD+ settings import and the requested independent native Escape-menu MCM entry remain unresolved. No third-party config writer, assets or private native pointers are added by this release.

Intermittent dropdown text loss remains a live investigation. Controller navigation is not provided.
