// @ts-check

/**
 * Shared pointer-drag lifecycle for "press-drag-transform" gestures — the
 * gesture class where the user presses a handle, drags, and a value changes
 * continuously with the pointer (resize handles, sliders, splitters,
 * reorder-by-delta). This is deliberately NOT drag-and-drop: there is no drop
 * target and no transfer payload, so the drag-and-drop modifiers (which wrap a
 * transfer-DnD library) don't fit. A press-drag-transform needs pointer capture
 * so the drag survives the pointer leaving the small handle — which this owns.
 *
 * It centralizes ONLY the universal lifecycle; everything domain-specific (what
 * origin state to capture, how to compute the next value, how to preview it,
 * what to commit) stays in the caller's handlers. It is a composable function
 * (not a modifier) because callers are typically themselves modifiers holding
 * per-instance drag state, and a modifier cannot apply another modifier — so
 * each caller invokes this from its own modifier body and returns the teardown.
 *
 * What the primitive owns:
 *  - the four pointer listeners (`pointerdown` / `move` / `up` / `cancel`) and
 *    their teardown;
 *  - the primary-button gate (only button 0 starts a drag);
 *  - single-drag re-entrancy (a second press is ignored while one is active);
 *  - `setPointerCapture` / `releasePointerCapture` (with the safe try/catch the
 *    capture can throw if the element was removed mid-drag);
 *  - `preventDefault` / `stopPropagation` on a started press, so the gesture
 *    doesn't also trigger a click, a text selection, or a drag beneath it;
 *  - an OPTIONAL dragging-state class toggle (some affordances want a
 *    `--dragging` style hook, others don't — hence opt-in via `draggingClass`).
 *
 * What the caller owns (via `handlers`):
 *  - `onDown(event)` — capture origin state; return `false` to ABORT the drag
 *    (e.g. an anchor element isn't resolvable yet, or the handle is out of
 *    range). Any other return value (including `undefined`) starts the drag.
 *  - `onMove(event)` — compute the next value and paint a live preview. Only
 *    fires while a drag is active, so no internal guard is needed.
 *  - `onUp(event)` — compute the final value and commit it. Runs BEFORE the
 *    primitive releases capture / clears the dragging class.
 *  - `onCancel(event)` — release any preview without committing.
 *
 * @param {Element} element - The handle the gesture is bound to.
 * @param {{
 *   onDown?: (event: PointerEvent) => (boolean|void),
 *   onMove?: (event: PointerEvent) => void,
 *   onUp?: (event: PointerEvent) => void,
 *   onCancel?: (event: PointerEvent) => void,
 * }} handlers - The domain-specific drag callbacks.
 * @param {{ draggingClass?: string }} [options] - When `draggingClass` is set,
 *   the primitive adds it on a started press and removes it on release/cancel.
 * @returns {() => void} A teardown function that removes the listeners. Return
 *   it straight from an `ember-modifier` body so it runs on destroy.
 */
export function installPointerDrag(element, handlers, options = {}) {
  const { draggingClass } = options;
  let pointerId = null;

  function onPointerDown(event) {
    // Only the primary button starts a drag, and never while one is already
    // active (a second pointer must not clobber the in-flight gesture).
    if (event.button !== 0 || pointerId != null) {
      return;
    }
    // The caller captures its origin state here and may veto the drag by
    // returning `false` (e.g. the anchor element isn't available yet).
    if (handlers.onDown?.(event) === false) {
      return;
    }
    pointerId = event.pointerId;
    try {
      element.setPointerCapture(pointerId);
    } catch {
      // Capturing can throw if the element was detached between the press
      // and this call; the drag still works via the document-level events.
    }
    if (draggingClass) {
      element.classList.add(draggingClass);
    }
    event.preventDefault();
    event.stopPropagation();
  }

  function onPointerMove(event) {
    if (pointerId == null) {
      return;
    }
    handlers.onMove?.(event);
  }

  function onPointerUp(event) {
    if (pointerId == null) {
      return;
    }
    // Commit before the primitive tears the capture down, so the caller still
    // sees a consistent drag state while it reads the final value.
    handlers.onUp?.(event);
    finish();
  }

  function onPointerCancel(event) {
    if (pointerId == null) {
      return;
    }
    handlers.onCancel?.(event);
    finish();
  }

  function finish() {
    if (pointerId != null) {
      try {
        element.releasePointerCapture(pointerId);
      } catch {
        // The capture is released automatically if the element was removed
        // mid-drag; safe to ignore.
      }
    }
    if (draggingClass) {
      element.classList.remove(draggingClass);
    }
    pointerId = null;
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
