// @ts-check
import { modifier } from "ember-modifier";
import { installPointerDrag } from "discourse/ui-kit/lib/pointer-drag";

/**
 * Pointer-drag handler for a column gridline handle. The line follows
 * the pointer, growing the left column; by default the immediate right
 * column shrinks to match (split-pane), and with Alt held the columns to
 * the right all shrink in proportion instead. The result persists as the
 * layout's `columnFractions`.
 *
 * Live preview is written to the grid element's `--d-block-layout-cols`
 * custom property. During a drag nothing mutates the layout's tracked
 * state, so Glimmer never re-applies `style={{containerStyle}}` and
 * clobbers it; the pointerup commit triggers one structural re-render
 * that replaces the inline preview with the stored value. On cancel the
 * inline preview is removed so the stored value owns the style again.
 *
 * Arguments (positional):
 *   1. `getGridElement` — `() =>` the grid container `<div>`, read on
 *      pointerdown (by which time the overlay's `didInsert` has run).
 *   2. `leftTrack` — 0-indexed column on the LEFT of this line (the line
 *      sits between `leftTrack` and `leftTrack + 1`).
 *   3. `computeFractions` — `(pxWidths, leftTrack, deltaPx) => number[]`,
 *      the pure resize math (`resizeColumnFractions`); the 4th arg
 *      carries `{ proportional }`, set from the live Alt key.
 *   4. `onCommit` — `(fractions) => void`, called once on pointerup.
 *   5. `onStart` — `() => void`, called on pointerdown; selects the
 *      layout being resized.
 */
export default modifier(
  (
    element,
    [getGridElement, leftTrack, computeFractions, onCommit, onStart]
  ) => {
    let gridEl = null;
    let originX = 0;
    let pxWidths = null;
    let nextFractions = null;

    function readColumnWidths(el) {
      return (getComputedStyle(el).gridTemplateColumns || "")
        .split(" ")
        .map((part) => parseFloat(part))
        .filter((value) => !Number.isNaN(value));
    }

    function reset() {
      gridEl = null;
      pxWidths = null;
      nextFractions = null;
    }

    return installPointerDrag(
      element,
      {
        onDown(event) {
          gridEl = getGridElement?.();
          if (!gridEl) {
            return false;
          }
          pxWidths = readColumnWidths(gridEl);
          if (leftTrack < 0 || leftTrack + 1 >= pxWidths.length) {
            return false;
          }
          originX = event.clientX;
          // Selecting on grab means the inspector tracks the layout being
          // resized (every interaction with a block selects it).
          onStart?.();
        },
        onMove(event) {
          if (!pxWidths) {
            return;
          }
          // Read `altKey` per move so toggling it mid-drag flips the preview
          // between split-pane and proportional.
          nextFractions = computeFractions(
            pxWidths,
            leftTrack,
            event.clientX - originX,
            {
              proportional: event.altKey,
            }
          );
          if (gridEl) {
            gridEl.style.setProperty(
              "--d-block-layout-cols",
              nextFractions.map((fraction) => `${fraction}fr`).join(" ")
            );
          }
        },
        onUp() {
          if (nextFractions) {
            // Commit only — the structural re-render replaces the inline
            // preview with the persisted value, so no manual clear is needed.
            onCommit?.(nextFractions);
          }
          reset();
        },
        onCancel() {
          gridEl?.style.removeProperty("--d-block-layout-cols");
          reset();
        },
      },
      { draggingClass: "--dragging" }
    );
  }
);
