import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";

/**
 * Wires the "press-drag-transform" pointer lifecycle to an element — the
 * gesture class where the user presses, drags, and a value changes continuously
 * with the pointer (resize handles, sliders, splitters, knobs). This is NOT
 * drag-and-drop: there is no drop target and no transfer payload, so the
 * drag-and-drop modifiers don't fit. Unlike `d-draggable` (a coarse mouse/touch
 * "move/scrub" modifier that mixes in the HTML5 drag events and toggles a global
 * `body.dragging` class), this uses unified Pointer Events with
 * `setPointerCapture`, gates on the primary button, and stops the gesture from
 * also triggering a click / selection / a drag beneath it — so it's safe on a
 * small handle embedded in other interactive UI.
 *
 * State lives in instance fields (no mutated closures). The lifecycle is owned
 * here; everything domain-specific (what origin to capture, how to compute the
 * next value, how to preview it, what to commit) stays in the caller's handlers.
 *
 * @example
 * <span {{dPointerDrag
 *   onDown=this.onDown
 *   onMove=this.onMove
 *   onUp=this.onUp
 *   onCancel=this.onCancel
 *   draggingClass="--dragging"
 * }} />
 *
 * Handlers (all optional):
 *  - `onDown(event)` — capture origin state; return `false` to ABORT the drag
 *    (e.g. an anchor isn't resolvable). Any other return starts it.
 *  - `onMove(event)` — compute + preview. Only fires during an active drag.
 *  - `onUp(event)` — compute + commit. Runs BEFORE capture is released.
 *  - `onCancel(event)` — release any preview without committing.
 *  - `draggingClass` — optional class toggled on the element while dragging.
 */
export default class DPointerDragModifier extends Modifier {
  #element = null;
  #pointerId = null;
  #installed = false;
  #onDown = null;
  #onMove = null;
  #onUp = null;
  #onCancel = null;
  #draggingClass = null;

  #handlePointerDown = (event) => {
    // Only the primary button starts a drag, and never while one is already
    // active (a second pointer must not clobber the in-flight gesture).
    if (event.button !== 0 || this.#pointerId != null) {
      return;
    }
    // The caller captures its origin state here and may veto by returning false.
    if (this.#onDown?.(event) === false) {
      return;
    }
    this.#pointerId = event.pointerId;
    try {
      this.#element.setPointerCapture(this.#pointerId);
    } catch {
      // Capturing can throw if the element was detached between the press and
      // here; the drag still works via the document-level events.
    }
    if (this.#draggingClass) {
      this.#element.classList.add(this.#draggingClass);
    }
    event.preventDefault();
    event.stopPropagation();
  };

  #handlePointerMove = (event) => {
    if (this.#pointerId == null) {
      return;
    }
    this.#onMove?.(event);
  };

  #handlePointerUp = (event) => {
    if (this.#pointerId == null) {
      return;
    }
    // Commit before releasing capture, so the caller sees a consistent drag
    // state while it reads the final value.
    this.#onUp?.(event);
    this.#finishDrag();
  };

  #handlePointerCancel = (event) => {
    if (this.#pointerId == null) {
      return;
    }
    this.#onCancel?.(event);
    this.#finishDrag();
  };

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#cleanup());
  }

  modify(
    element,
    _positional,
    { onDown, onMove, onUp, onCancel, draggingClass }
  ) {
    this.#element = element;
    // Refresh the handler refs every run so arg changes are picked up; the DOM
    // listeners themselves are installed once (they read these fields live).
    this.#onDown = onDown;
    this.#onMove = onMove;
    this.#onUp = onUp;
    this.#onCancel = onCancel;
    this.#draggingClass = draggingClass;

    if (!this.#installed) {
      element.addEventListener("pointerdown", this.#handlePointerDown);
      element.addEventListener("pointermove", this.#handlePointerMove);
      element.addEventListener("pointerup", this.#handlePointerUp);
      element.addEventListener("pointercancel", this.#handlePointerCancel);
      this.#installed = true;
    }
  }

  #finishDrag() {
    if (this.#pointerId != null) {
      try {
        this.#element.releasePointerCapture(this.#pointerId);
      } catch {
        // Released automatically if the element was removed mid-drag.
      }
    }
    if (this.#draggingClass) {
      this.#element.classList.remove(this.#draggingClass);
    }
    this.#pointerId = null;
  }

  #cleanup() {
    const el = this.#element;
    if (!el) {
      return;
    }
    el.removeEventListener("pointerdown", this.#handlePointerDown);
    el.removeEventListener("pointermove", this.#handlePointerMove);
    el.removeEventListener("pointerup", this.#handlePointerUp);
    el.removeEventListener("pointercancel", this.#handlePointerCancel);
    if (this.#draggingClass) {
      el.classList.remove(this.#draggingClass);
    }
  }
}
