# Preview 0.1.55

Fixed disappearing controls when scrolling fully expanded, two-column settings pages such as Epic LUT Settings.

- Scroll positions and clipping use each column's rows instead of a flat registration slice.
- Shorter columns retain their final rows while longer columns continue scrolling.
- Keyboard selection, scrollbar limits, collapsed sections and compact layouts use the same row positions.

Epic LUT's settings writer, registered controls and saved values are preserved. Expanded/uneven columns, wrapped text, pointer edits and keyboard navigation are covered by a focused regression. In-game visual confirmation remains separate from offline checks.
