import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";

// Suppressing every browser touch gesture suits a small handle, which is what
// most consumers of this are.
const DEFAULT_TOUCH_ACTION = "none";

/**
 * Reflects the wanted `touch-action` onto the element for the stylesheet to
 * pick up. Separate from the gesture registration because the declaration has to
 * be in place before a touch begins, so it is refreshed whenever the args
 * change rather than frozen when the gesture was installed.
 *
 * @param {HTMLElement} element - The element carrying the gesture.
 * @param {string} [touchAction] - A token the stylesheet maps; see its docs.
 */
function syncTouchAction(element, touchAction) {
  element.setAttribute(
    "data-pointer-drag",
    touchAction ?? DEFAULT_TOUCH_ACTION
  );
}

/**
 * Wires the "press-drag-transform" pointer lifecycle to an element: the gesture
 * class where the user presses, drags, and a value changes continuously with the
 * pointer (resize handles, sliders, splitters, knobs). Used by the
 * default-exported modifier below, and exported so a consumer can install the
 * gesture imperatively when a template modifier doesn't fit, which is how
 * `dResizeEdge` layers its splitter semantics on top of one shared engine.
 *
 * This is NOT drag-and-drop: there is no drop target and no transfer payload, so
 * the `d-drag-and-drop-*` modifiers don't fit. The `onDrag*` callback names
 * describe this gesture's lifecycle (start, move, end, cancel), not a transfer.
 *
 * Unified Pointer Events with `setPointerCapture` cover mouse, touch and pen
 * without per-input branching. Only the primary button starts a gesture, and
 * every subsequent event must carry the same `pointerId`, so a second finger
 * landing on the element cannot drive or end a gesture the first one owns.
 *
 * The lifecycle is owned here; everything domain-specific (what origin to
 * capture, how to compute the next value, how to preview it, what to commit)
 * stays in the caller's handlers.
 *
 * @param {HTMLElement} element - The element the gesture is bound to.
 * @param {() => Object} getArgsRef - Closure returning the latest args, read on
 *   every event so arg changes take effect without re-registering. Args shape
 *   matches the modifier's named args, documented below.
 * @returns {() => void} Cleanup function. Releases an in-flight capture, so a
 *   gesture interrupted by teardown does not strand the pointer. Caller invokes
 *   it once on teardown.
 */
export function registerPointerDrag(element, getArgsRef) {
  let pointerId = null;
  let originX = 0;
  let originY = 0;
  // Latches true once the pointer has reached `threshold`, and stays true for
  // the rest of the gesture: returning inside the threshold must not start
  // suppressing movement again mid-drag.
  let engaged = false;
  // The class actually added at the start of this gesture. `draggingClass` can
  // change between gestures, and removing the current arg's value would leave
  // the one really on the element behind.
  let appliedClass = null;

  const finish = () => {
    if (pointerId !== null) {
      try {
        element.releasePointerCapture(pointerId);
      } catch {
        // Already released if the element was removed mid-gesture.
      }
    }
    if (appliedClass) {
      element.classList.remove(appliedClass);
      appliedClass = null;
    }
    pointerId = null;
    engaged = false;
  };

  const onPointerDown = (event) => {
    // Never take over a gesture already in flight: doing so would overwrite the
    // tracked pointer and strand the first one's capture.
    if (event.button !== 0 || pointerId !== null) {
      return;
    }
    // Capture first, before telling anyone a gesture started. Capture is what
    // routes the rest of the gesture back to this element, so without it a
    // pointer leaving the element would never deliver its release and the
    // in-flight guard would then reject every later press. Abort rather than
    // begin a gesture that cannot finish.
    try {
      element.setPointerCapture(event.pointerId);
    } catch {
      return;
    }

    const releaseCapture = () => {
      try {
        element.releasePointerCapture(event.pointerId);
      } catch {
        // Already gone if the element was detached in between.
      }
    };

    const args = getArgsRef();
    // The caller captures its origin state here and may veto by returning false.
    if (args.onDragStart?.(event) === false) {
      releaseCapture();
      return;
    }

    pointerId = event.pointerId;
    originX = event.clientX;
    originY = event.clientY;
    engaged = !(args.threshold > 0);

    if (args.draggingClass) {
      appliedClass = args.draggingClass;
      element.classList.add(appliedClass);
    }

    // Only an accepted press is suppressed. A secondary button, a press during
    // an active gesture, or a vetoed one must reach whatever else was listening.
    event.preventDefault();
    if (args.stopPropagation) {
      event.stopPropagation();
    }
  };

  const onPointerMove = (event) => {
    if (pointerId === null || event.pointerId !== pointerId) {
      return;
    }
    const args = getArgsRef();
    if (!engaged) {
      const threshold = args.threshold ?? 0;
      if (
        Math.hypot(event.clientX - originX, event.clientY - originY) < threshold
      ) {
        return;
      }
      engaged = true;
    }
    args.onDrag?.(event);
  };

  const onPointerUp = (event) => {
    if (pointerId === null || event.pointerId !== pointerId) {
      return;
    }
    // Commit before releasing capture, so the caller sees a consistent gesture
    // state while it reads the final value. Finalised in a `finally` so a
    // throwing callback cannot leave the gesture active and reject every later
    // press.
    try {
      getArgsRef().onDragEnd?.(event);
    } finally {
      finish();
    }
  };

  const onPointerCancel = (event) => {
    if (pointerId === null || event.pointerId !== pointerId) {
      return;
    }
    const args = getArgsRef();
    try {
      if (args.cancelCommits) {
        args.onDragEnd?.(event);
      } else {
        args.onDragCancel?.(event);
      }
    } finally {
      finish();
    }
  };

  // `touch-action` has to be in effect before the gesture starts, or the browser
  // has already claimed the touch as a scroll. Expressed as an attribute the
  // stylesheet maps, rather than an inline style, because consumers bind `style`
  // and would clobber it. Refreshed by `syncTouchAction` so a consumer that
  // changes orientation between gestures is not stuck with the first value.
  syncTouchAction(element, getArgsRef().touchAction);

  element.addEventListener("pointerdown", onPointerDown);
  element.addEventListener("pointermove", onPointerMove);
  element.addEventListener("pointerup", onPointerUp);
  element.addEventListener("pointercancel", onPointerCancel);

  return () => {
    finish();
    element.removeEventListener("pointerdown", onPointerDown);
    element.removeEventListener("pointermove", onPointerMove);
    element.removeEventListener("pointerup", onPointerUp);
    element.removeEventListener("pointercancel", onPointerCancel);
    element.removeAttribute("data-pointer-drag");
  };
}

/**
 * Binds the press-drag-transform gesture to an element. Thin Ember-modifier
 * wrapper around {@link registerPointerDrag}.
 *
 * @example
 * <span {{dPointerDrag
 *   onDragStart=this.onDragStart
 *   onDrag=this.onDrag
 *   onDragEnd=this.onDragEnd
 *   onDragCancel=this.onDragCancel
 *   draggingClass="--dragging"
 * }} />
 *
 * Args (named, all optional):
 *  - `onDragStart(event)` — capture origin state; return `false` to ABORT the
 *    gesture (e.g. an anchor isn't resolvable). Any other return starts it.
 *  - `onDrag(event)` — compute + preview. Only fires during an active gesture,
 *    and only once `threshold` has been exceeded.
 *  - `onDragEnd(event)` — compute + commit. Runs BEFORE capture is released.
 *  - `onDragCancel(event)` — release any preview without committing.
 *  - `draggingClass` — class toggled on the element for the gesture's duration.
 *  - `threshold` — pixels of travel, measured as a straight line from the press
 *    origin, that `onDrag` waits for before it starts firing. Reaching the
 *    distance is enough; it does not have to be exceeded. Suppresses the jitter
 *    of a click that was never meant to be a drag. Defaults to `0`. Read when
 *    the gesture starts: raising it mid-gesture will not re-suppress movement,
 *    because the latch only opens once.
 *  - `stopPropagation` — whether an accepted press also stops propagating.
 *    Defaults to `false`: document-level listeners (click-outside dismissal,
 *    card and menu closers) depend on seeing `pointerdown`, so suppression is
 *    opt-in for the handles that genuinely need to isolate themselves.
 *  - `cancelCommits` — whether `pointercancel` commits via `onDragEnd` instead
 *    of discarding via `onDragCancel`. Defaults to `false`. A splitter wants
 *    `true`: an OS-interrupted resize should keep the size the user dragged to.
 *  - `touchAction` — which browser touch gestures the element gives up,
 *    reflected as `data-pointer-drag` and mapped by
 *    `app/assets/stylesheets/common/ui-kit/d-pointer-drag.scss`. Defaults to
 *    `"none"`, which suits a small handle. Anything large enough that a user
 *    might start a scroll or a pinch-zoom on it wants `"pan-x"`, `"pan-y"`,
 *    `"pinch-zoom"` or `"manipulation"` instead. Only those tokens are mapped;
 *    an unrecognised value leaves `touch-action` at its inherited value, so add
 *    a rule to that stylesheet rather than inventing a token here.
 *
 * A single element supports one registration. Two would each claim the same
 * pointer capture and the same attribute, and tearing either down would strand
 * the other's gesture.
 */
export default class DPointerDragModifier extends Modifier {
  #args = null;
  #cleanup = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#teardown());
  }

  modify(element, _positional, named) {
    // Refreshed every run so arg changes are picked up; the gesture itself is
    // installed once and reads these live.
    this.#args = named;

    this.#cleanup ??= registerPointerDrag(element, () => this.#args);

    // Re-reflected here rather than only at registration: the declaration has to
    // be in place before a touch begins, so a consumer that changes it between
    // gestures needs the next one to see the new value.
    syncTouchAction(element, named.touchAction);
  }

  #teardown() {
    this.#cleanup?.();
    this.#cleanup = null;
  }
}
