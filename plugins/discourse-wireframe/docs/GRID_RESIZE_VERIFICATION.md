# Grid cell resize regression

Verified on 2026-09-10. This concerns spanning cells, not the separate proposed
row-track height controls.

## Cause

`DResizeHandles` renders a base handle class plus standalone direction modifiers
such as `--e`. The grid stylesheet still used suffixed selectors such as
`.wireframe-block-chrome__resize-handle--e`. Those selectors matched no handles,
leaving both filled-cell resize and empty-cell merge handles without their
dimensions and edge positions.

The repair uses `&.--n` through `&.--nw` under the existing handle class. The core
pointer primitive and resize callbacks are unchanged.

## Coverage gap

The existing `grid-overlay-rendering-test.gjs` regression dispatches synthetic
pointer events directly to a handle and replaces `resizeSlot` with a spy. This
guards service wiring, but bypasses hit testing and does not assert a changed
span. The rendering suite also runs without the plugin's admin stylesheet.
Pure geometry tests cannot detect a stylesheet/markup mismatch either.

The new `resize_wireframe_grid_cells_spec.rb` loads the actual editor stylesheet,
checks all eight filled-cell handles have dimensions and the correct positions,
and performs native pointer drags. It checks rendered column and row spans for
filled cells and merged empty cells. Corner drags cover simultaneous changes to
both axes, including shrinking.

Before the fix, the geometry check failed and the empty-cell drag timed out on
a hidden handle. After recompiling the test CSS, both flows passed with seed
`54492`. Matching only a callback or a DOM node is not enough evidence for this
interaction: the handle must be reachable and the rendered span must change.

The post-drag screenshot also shows the inspector's Column and Row inputs still
displaying the original `2` / `2` while the rendered cell spans `1 / 4` on both
axes. Inspector value synchronization needs a separate regression and follow-up;
the handle repair does not establish that those inputs refresh after a drag.

## Local CSS test cache

System tests reuse `tmp/cache/assets/test/stylesheet-manifest-test_0`. After a
stylesheet edit, a new test process can still serve the previous compiled CSS.
Move the relevant test manifest aside before rerunning a CSS regression so its
content hash is rebuilt. Do not change application styles or weaken assertions
to compensate for a stale test build.
