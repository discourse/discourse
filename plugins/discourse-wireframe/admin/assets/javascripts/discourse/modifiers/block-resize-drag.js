// @ts-check
import { modifier } from "ember-modifier";

const MIN_DIM = 40;

/**
 * Resolves the active axis and anchor for a given direction code.
 * Directions match the compass-point convention painted on the chrome:
 *
 *   nw  n  ne
 *    w     e
 *   sw  s  se
 *
 * - `n` / `s` move the top / bottom edge → height-only.
 * - `e` / `w` move the right / left edge → width-only.
 * - Corner directions move both edges.
 *
 * The "anchor" is the OPPOSITE corner (or edge midpoint) of the
 * direction the user grabs — that's the point that stays fixed while
 * the block grows / shrinks. `signX` / `signY` translate raw pointer
 * deltas into width / height deltas (e.g. dragging `w` LEFT increases
 * width, so signX is `-1` for `w` directions).
 *
 * @param {string} direction
 * @returns {{signX: number, signY: number}}
 */
function deltaSigns(direction) {
  let signX = 0;
  let signY = 0;
  if (direction.includes("e")) {
    signX = 1;
  }
  if (direction.includes("w")) {
    signX = -1;
  }
  if (direction.includes("s")) {
    signY = 1;
  }
  if (direction.includes("n")) {
    signY = -1;
  }
  return { signX, signY };
}

/**
 * Pointer-event drag handler for one of the 8-point resize handles
 * painted on a selected block. Each handle binds its own instance of
 * the modifier with its compass-point `direction`.
 *
 * Behaviour:
 *   - Pointer-down anywhere on the handle starts a drag.
 *   - Pointer-move computes the new width / height with the handle's
 *     direction in mind: corner handles change both dims, edge
 *     handles change one.
 *   - Aspect-lock is on by default for CORNER handles (and respects
 *     the consumer's `lockedAspectRatio`). Edge handles never lock —
 *     pulling just one edge is the whole point of an edge handle.
 *     Holding shift on a corner handle releases the lock.
 *   - `onPreview` fires on every move so the consumer can paint a
 *     live size preview; `onCommit` fires once on pointerup.
 *
 * Arguments (positional):
 *   1. `getBlockElement` — function returning the block's outer `<div>`
 *      whose bounding rect anchors the drag.
 *   2. `direction` — one of `"nw"|"n"|"ne"|"e"|"se"|"s"|"sw"|"w"`.
 *   3. `lockedAspectRatio` — `null` for "derive at drag start"; a
 *      positive finite number to force a specific aspect.
 *   4. `onPreview({width, height})` — called on every pointermove.
 *   5. `onCommit({width, height})` — called once on pointerup.
 */
export default modifier(
  (
    element,
    [getBlockElement, direction, lockedAspectRatio, onPreview, onCommit]
  ) => {
    let originRect = null;
    let originX = 0;
    let originY = 0;
    let pointerId = null;
    let aspect = null;
    const { signX, signY } = deltaSigns(direction);

    function compute(event, shiftHeld) {
      if (!originRect) {
        return null;
      }
      const deltaX = (event.clientX - originX) * signX;
      const deltaY = (event.clientY - originY) * signY;

      let width = originRect.width;
      let height = originRect.height;

      if (signX !== 0) {
        width = originRect.width + deltaX;
      }
      if (signY !== 0) {
        height = originRect.height + deltaY;
      }

      // Aspect-lock is on for ALL handles by default. For corner
      // drags either axis can lead (whichever moved more in
      // proportion). For edge drags the dragged axis drives, and the
      // other axis follows via the aspect ratio. Shift releases the
      // lock for the rare case where the user wants a free pull.
      const locked = aspect != null && !shiftHeld;
      if (locked) {
        if (signX !== 0 && signY !== 0) {
          // Corner: pick the axis with the larger proportional change.
          const widthChange = Math.abs(width - originRect.width);
          const heightChange = Math.abs(height - originRect.height);
          if (widthChange >= heightChange) {
            height = width / aspect;
          } else {
            width = height * aspect;
          }
        } else if (signX !== 0) {
          // Edge with horizontal sign (`e` / `w`): width leads.
          height = width / aspect;
        } else if (signY !== 0) {
          // Edge with vertical sign (`n` / `s`): height leads.
          width = height * aspect;
        }
      }

      return {
        width: Math.max(MIN_DIM, Math.round(width)),
        height: Math.max(MIN_DIM, Math.round(height)),
      };
    }

    function onPointerDown(event) {
      if (event.button !== 0) {
        return;
      }
      const blockEl = getBlockElement?.();
      if (!blockEl) {
        return;
      }
      event.preventDefault();
      event.stopPropagation();
      originRect = blockEl.getBoundingClientRect();
      originX = event.clientX;
      originY = event.clientY;
      aspect =
        typeof lockedAspectRatio === "number" &&
        Number.isFinite(lockedAspectRatio) &&
        lockedAspectRatio > 0
          ? lockedAspectRatio
          : originRect.width / Math.max(originRect.height, 1);
      pointerId = event.pointerId;
      element.setPointerCapture(pointerId);
    }

    function onPointerMove(event) {
      if (pointerId == null) {
        return;
      }
      const next = compute(event, event.shiftKey);
      if (next) {
        onPreview?.(next);
      }
    }

    function onPointerUp(event) {
      if (pointerId == null) {
        return;
      }
      const final = compute(event, event.shiftKey);
      try {
        element.releasePointerCapture(pointerId);
      } catch {
        // The capture is automatically released if the element was
        // removed mid-drag; safe to ignore.
      }
      pointerId = null;
      originRect = null;
      aspect = null;
      if (final) {
        onCommit?.(final);
      }
    }

    function onPointerCancel() {
      if (pointerId == null) {
        return;
      }
      try {
        element.releasePointerCapture(pointerId);
      } catch {
        // Same rationale as above.
      }
      pointerId = null;
      originRect = null;
      aspect = null;
    }

    element.addEventListener("pointerdown", onPointerDown);
    element.addEventListener("pointermove", onPointerMove);
    element.addEventListener("pointerup", onPointerUp);
    element.addEventListener("pointercancel", onPointerCancel);

    return () => {
      element.removeEventListener("pointerdown", onPointerDown);
      element.removeEventListener("pointermove", onPointerMove);
      element.removeEventListener("pointerup", onPointerUp);
      element.removeEventListener("pointercancel", onPointerCancel);
    };
  }
);
