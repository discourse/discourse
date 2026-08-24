import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";
import ElementClassLease from "discourse/lib/element-class-lease";

/**
 * The `touch-action` tokens `d-pointer-drag.scss` has a rule for. A token
 * without one leaves the element at `auto`, so the two must move together.
 */
export type TouchActionToken =
  | "none"
  | "pan-x"
  | "pan-y"
  | "pinch-zoom"
  | "manipulation";

/**
 * Suppressing every browser touch gesture suits a small handle, which is what
 * most consumers of this are.
 */
const DEFAULT_TOUCH_ACTION: TouchActionToken = "none";

/** A point in client coordinates. */
type Point = Readonly<{ x: number; y: number }>;

/**
 * Where the gesture is, reported alongside every callback's event.
 *
 * A snapshot, not a live view. A fresh one is built per dispatch, so a consumer
 * that stores it keeps the numbers it was given.
 */
export interface DPointerDragInfo {
  /** Where the press landed. */
  readonly origin: Point;

  /** Where the pointer is now. */
  readonly current: Point;

  /** How far the pointer has travelled since the press. */
  readonly delta: Point;

  /**
   * Whether `onDrag` has fired at least once for THIS gesture. It separates a
   * drag from a click that landed on the handle.
   *
   * This is not the same as passing `threshold`. With no threshold a gesture can
   * report from the press onwards, but it may still have reported nothing.
   */
  readonly moved: boolean;
}

interface DPointerDragSignature {
  /** The element the gesture is bound to. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Return `false` to ABORT the gesture, for example when an anchor cannot
       * be resolved. Any other return starts it. An exception here is rethrown
       * after the pointer capture is released, and no gesture starts.
       */
      onDragStart?: (
        event: PointerEvent,
        info: DPointerDragInfo
      ) => boolean | void;

      /**
       * Compute and preview the new value. Only fires during an active gesture,
       * and only once `threshold` has been exceeded.
       */
      onDrag?: (event: PointerEvent, info: DPointerDragInfo) => void;

      /**
       * Compute and commit the new value. Runs BEFORE the pointer capture is
       * released. Fires for any release on this element, including one that never
       * reached `threshold` and saw no `onDrag`. Use `info.moved` to tell them apart.
       */
      onDragEnd?: (event: PointerEvent, info: DPointerDragInfo) => void;

      /**
       * Release any preview without committing. Neither this nor `onDragEnd`
       * runs when the element is destroyed mid-gesture; see the modifier's own
       * docs for what to do with state that outlives the handle.
       */
      onDragCancel?: (event: PointerEvent, info: DPointerDragInfo) => void;

      /**
       * A class toggled on the element for the gesture's duration. A single
       * token: a value with whitespace in it is rejected by the DOM, which costs
       * the drag its styling but leaves the gesture working.
       */
      draggingClass?: string;

      /**
       * A class held on `document.body` for the gesture's duration, for a cursor
       * that has to survive the pointer leaving the handle. Whether that happens
       * by itself is engine-dependent, so the rule cannot be left to the element.
       * It reaches only what inherits `cursor`, so anything declaring its own
       * still wins over it, and a gesture that must hold the cursor everywhere
       * wants an overlay instead. Held by count, so two gestures asking for the
       * same class both keep it until the last one ends.
       *
       * Reach for a class on a shared ancestor, not this, when the target is
       * simply outside the dragged element's subtree — a sibling is still
       * reachable from the parent the two have in common.
       */
      bodyClass?: string;

      /**
       * Pixels of travel, measured as a straight line from the press origin, that
       * `onDrag` waits for before it starts firing. Reaching the distance is
       * enough; it does not have to be exceeded. Suppresses the jitter of a click
       * that was never meant to be a drag. Defaults to `0`. Read live until the
       * distance is reached; only the latch is permanent, so raising it after
       * movement has engaged will not re-suppress a gesture already under way.
       */
      threshold?: number;

      /**
       * Whether an accepted press also stops propagating. Defaults to `false`:
       * document-level listeners (click-outside dismissal, card and menu closers)
       * depend on seeing `pointerdown`, so suppression is opt-in for the handles
       * that genuinely need to isolate themselves.
       */
      stopPropagation?: boolean;

      /**
       * Whether a press on a descendant keeps behaving like a press on that
       * descendant. Defaults to `false`, which suits a handle: the press is
       * cancelled, moves no focus, and this element takes the pointer capture.
       *
       * When set — for a surface wrapping interactive content — descendants keep
       * focus, selection, `mousedown`, and a tap's `click`; a drag's `click` is
       * still suppressed, and native drag-and-drop is refused while the gesture
       * is live.
       */
      preservePress?: boolean;

      /**
       * Whether a gesture that ends without the pointer being released on this
       * element — `pointercancel`, or the capture being taken away — commits via
       * `onDragEnd` instead of discarding via `onDragCancel`. Defaults to
       * `false`. A splitter wants `true`: an OS-interrupted resize should keep
       * the size the user dragged to.
       */
      cancelCommits?: boolean;

      /**
       * Which browser touch gestures the element gives up, reflected as
       * `data-pointer-drag` and mapped by
       * `app/assets/stylesheets/common/ui-kit/d-pointer-drag.scss`. Defaults to
       * `"none"`, which suits a small handle. Anything large enough that a user
       * might start a scroll or a pinch-zoom on it wants `"pan-x"`, `"pan-y"`,
       * `"pinch-zoom"` or `"manipulation"` instead.
       *
       * The union is closed against that stylesheet, so widen it only alongside
       * a rule there: `touch-action` is not inherited, and a token with no rule
       * behind it leaves the element at `auto`, where the browser claims the
       * touch as a scroll and the gesture dies through `pointercancel`.
       */
      touchAction?: TouchActionToken;
    };
    Positional: [];
  };
}

/**
 * The gesture's named args, for a consumer driving {@link registerPointerDrag}
 * imperatively rather than through the modifier.
 */
export type DPointerDragArgs = DPointerDragSignature["Args"]["Named"];

/**
 * The gesture holding each active pointer, keyed by `pointerId`, so a
 * registration that loses a contested pointer can be told to stand down.
 *
 * Keyed per pointer rather than kept as a single current owner, because two
 * gestures driven by two different pointers are both legitimately live.
 *
 * A pointer ID is a number, so this cannot be a `WeakMap`, and each entry holds
 * its element: an entry left behind holds a detached element alive, and a
 * later press reusing that ID would call into a registration that no longer
 * exists. Removing an entry the moment its gesture ends is therefore load-bearing
 * rather than housekeeping.
 *
 * The element is held beside the supersede callback so a claim rejected in the
 * same dispatch — a veto, a throw — can hand the pending capture it displaced
 * back to the entry's owner rather than releasing it into nothing.
 */
const pointerOwners = new Map<
  number,
  { captureTarget: Element; supersede: (event: PointerEvent) => void }
>();

/**
 * Drops all pointer-ownership bookkeeping. For tests only: a consumer of
 * {@link registerPointerDrag} that never invokes its cleanup would otherwise
 * leave an entry behind that releases the next gesture to reuse that pointer ID.
 */
export function resetPointerDragForTesting() {
  pointerOwners.clear();
}

/**
 * Reflects the wanted `touch-action` onto the element for the stylesheet to
 * pick up. Separate from the gesture registration because the declaration has to
 * be in place before a touch begins, so it is refreshed whenever the args
 * change rather than frozen when the gesture was installed.
 *
 * @param element - The element carrying the gesture.
 * @param touchAction - A token the stylesheet maps; see its docs.
 */
function syncTouchAction(element: HTMLElement, touchAction?: TouchActionToken) {
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
 * gesture imperatively when a template modifier does not fit.
 *
 * This is not a transfer operation: there is no drop target or payload. The
 * `onDrag*` callback names describe this gesture's lifecycle (start, move, end,
 * cancel).
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
 * @param element - The element the gesture is bound to.
 * @param getArgsRef - Closure returning the latest args, read on every event so
 *   arg changes take effect without re-registering.
 * @returns Cleanup function. Releases an in-flight capture, so a gesture
 *   interrupted by teardown does not strand the pointer. Caller invokes it once
 *   on teardown.
 */
export function registerPointerDrag(
  element: HTMLElement,
  getArgsRef: () => DPointerDragArgs
) {
  let pointerId: number | null = null;
  let originX = 0;
  let originY = 0;
  // Latches true once the pointer has reached `threshold`, and stays true for
  // the rest of the gesture: returning inside the threshold must not start
  // suppressing movement again mid-drag.
  let engaged = false;
  // Separate from `engaged`, which is already true at the press when no
  // threshold is set.
  let moved = false;
  // The class actually added at the start of this gesture. `draggingClass` can
  // change between gestures, so the value really on the element is snapshotted
  // rather than re-read when it is time to remove it.
  let appliedClass: string | null = null;
  let bodyClassLease: ElementClassLease | null = null;
  let capturedNode: Element = element;
  let watchingDocumentLoss = false;
  // Set by the cleanup below. A consumer can destroy its own registration from
  // inside `onDragStart`, and the rest of that dispatch still runs.
  let tornDown = false;

  const dragInfo = (event: PointerEvent): DPointerDragInfo => ({
    origin: { x: originX, y: originY },
    current: { x: event.clientX, y: event.clientY },
    delta: { x: event.clientX - originX, y: event.clientY - originY },
    moved,
  });

  const finish = () => {
    const finishedPointer = pointerId;
    const classToRemove = appliedClass;
    const finishedBodyClassLease = bodyClassLease;

    // Reset before touching the DOM: either call below can throw, and leaving
    // `pointerId` set would keep the gesture in flight forever.
    pointerId = null;
    engaged = false;
    moved = false;
    appliedClass = null;
    bodyClassLease = null;

    if (finishedPointer !== null) {
      // Only while the claim is still ours: a later claimant owns the entry from
      // the moment it supersedes us, and must not have it deleted underneath it.
      const owner = pointerOwners.get(finishedPointer);
      const stillOurs = !owner || owner.supersede === onSuperseded;

      if (owner && stillOurs) {
        pointerOwners.delete(finishedPointer);
      }
      if (stillOurs) {
        try {
          capturedNode.releasePointerCapture(finishedPointer);
        } catch {
          // Already released if the element was removed mid-gesture.
        }
      }
      capturedNode = element;
      unwatchDocumentLoss();
    }
    if (classToRemove) {
      // Unguarded: `appliedClass` is only ever set to a token `classList.add`
      // already accepted, and `remove` rejects exactly what `add` rejects.
      element.classList.remove(classToRemove);
    }
    finishedBodyClassLease?.release();
  };

  const watchDocumentLoss = () => {
    if (!watchingDocumentLoss) {
      document.addEventListener(
        "lostpointercapture",
        onLostPointerCapture,
        true
      );
      watchingDocumentLoss = true;
    }
  };

  const unwatchDocumentLoss = () => {
    if (watchingDocumentLoss) {
      document.removeEventListener(
        "lostpointercapture",
        onLostPointerCapture,
        true
      );
      watchingDocumentLoss = false;
    }
  };

  const transferCaptureToSurface = (event: PointerEvent) => {
    if (capturedNode === element) {
      return;
    }
    try {
      element.setPointerCapture(event.pointerId);
    } catch {
      return;
    }
    capturedNode = element;
    unwatchDocumentLoss();

    const owner = pointerOwners.get(event.pointerId);
    if (owner?.supersede === onSuperseded) {
      owner.captureTarget = element;
    }
  };

  /**
   * Ends the gesture the way the caller asked cancellation to behave. Shared by
   * `pointercancel` and by losing the capture, which are the same situation: the
   * gesture is over without the pointer having been released on this element.
   *
   * @param args - The current args.
   * @param event - The event ending the gesture.
   */
  const cancelGesture = (args: DPointerDragArgs, event: PointerEvent) => {
    const info = dragInfo(event);
    try {
      if (args.cancelCommits) {
        args.onDragEnd?.(event, info);
      } else {
        args.onDragCancel?.(event, info);
      }
    } finally {
      finish();
    }
  };

  /**
   * Ends this gesture because another registration has claimed the pointer it
   * was holding. Routed through `cancelGesture` so `cancelCommits` decides how
   * it reports, like any other end that is not a release on this element.
   *
   * Doubles as this registration's identity in `pointerOwners`: one stable
   * function per registration, so an entry can only be removed by its owner.
   *
   * @param event - The press that claimed the pointer away.
   */
  const onSuperseded = (event: PointerEvent) => {
    cancelGesture(getArgsRef(), event);
  };

  const onPointerDown = (event: PointerEvent) => {
    // Never take over a gesture already in flight: doing so would overwrite the
    // tracked pointer and strand the first one's capture.
    if (event.button !== 0 || pointerId !== null) {
      return;
    }
    const args = getArgsRef();
    const initialCaptureTarget =
      args.preservePress && event.target instanceof Element
        ? event.target
        : element;

    // Capture first, before telling anyone a gesture started. Capture is what
    // routes the rest of the gesture back to this element, so without it a
    // pointer leaving the element would never deliver its release and the
    // in-flight guard would then reject every later press. Abort rather than
    // begin a gesture that cannot finish.
    try {
      initialCaptureTarget.setPointerCapture(event.pointerId);
    } catch {
      return;
    }

    const releaseCapture = () => {
      try {
        initialCaptureTarget.releasePointerCapture(event.pointerId);
      } catch {
        // Already gone if the element was detached in between.
      }
    };

    // For a claim rejected during its own dispatch. The `setPointerCapture`
    // above displaced any earlier claimant's pending capture, so a plain
    // release here would clear the override entirely and leave that claimant's
    // live gesture uncaptured — latched until some later press happens to
    // supersede it, which a touch pointer's unreused ID never does. Handing the
    // capture back is the only exit that keeps the one-terminal-callback
    // guarantee; releasing is only right when there was no one to displace.
    const restoreDisplacedCapture = () => {
      const prior = pointerOwners.get(event.pointerId);
      if (!prior) {
        releaseCapture();
        return;
      }
      try {
        prior.captureTarget.setPointerCapture(event.pointerId);
      } catch {
        // The prior claimant's element is gone; nothing to hand back.
        releaseCapture();
      }
    };

    // Before the dispatch below, which reports them.
    originX = event.clientX;
    originY = event.clientY;
    moved = false;

    let vetoed;
    try {
      vetoed = args.onDragStart?.(event, dragInfo(event)) === false;
    } catch (error) {
      // Rethrown, because a throwing consumer is the consumer's bug. The capture
      // still has to go back: nothing else would release it.
      restoreDisplacedCapture();
      throw error;
    }
    // A registration torn down by its own `onDragStart` has already had its
    // listeners removed, so nothing is left to end a gesture installed now — and
    // claiming the pointer would leave an entry no one can remove.
    if (vetoed || tornDown) {
      restoreDisplacedCapture();
      return;
    }

    pointerId = event.pointerId;
    capturedNode = initialCaptureTarget;
    if (initialCaptureTarget !== element) {
      watchDocumentLoss();
    }
    engaged = !(args.threshold > 0);

    // A press bubbles, so an ancestor registration starts its own gesture from
    // the same event. Capture requested during `pointerdown` is only pending
    // until the dispatch ends and the last request wins, so the earlier claimant
    // keeps none of it and receives no terminal event at all — its in-flight
    // guard would then reject every later press. Tracked here rather than read
    // back through `hasPointerCapture`, which cannot tell a lost claim apart from
    // a pointer that was never real.
    const superseded = pointerOwners.get(event.pointerId);
    pointerOwners.set(event.pointerId, {
      captureTarget: initialCaptureTarget,
      supersede: onSuperseded,
    });

    if (args.draggingClass) {
      try {
        element.classList.add(args.draggingClass);
        // Only once it is really on the element, so `finish` never tries to
        // remove a token the DOM rejected.
        appliedClass = args.draggingClass;
      } catch {
        // A whitespace token is a caller mistake: it costs the drag its styling
        // but must not abort the gesture.
      }
    }
    if (args.bodyClass) {
      try {
        bodyClassLease = new ElementClassLease(document.body, args.bodyClass);
      } catch {
        // Same as above: a rejected token costs the page-level styling only.
      }
    }

    // Only an accepted press is suppressed. A secondary button, a press during
    // an active gesture, or a vetoed one must reach whatever else was listening.
    if (!args.preservePress) {
      event.preventDefault();
    }
    if (args.stopPropagation) {
      event.stopPropagation();
    }

    // Last, so this gesture is fully established before control passes to another
    // consumer's callback, which is free to throw.
    superseded?.supersede(event);
  };

  const onPointerMove = (event: PointerEvent) => {
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
    if (!moved) {
      transferCaptureToSurface(event);
    }
    // Latched before the dispatch, so this report already counts as movement.
    moved = true;
    args.onDrag?.(event, dragInfo(event));
  };

  const onPointerUp = (event: PointerEvent) => {
    if (pointerId === null || event.pointerId !== pointerId) {
      return;
    }
    // Commit before releasing capture, so the caller sees a consistent gesture
    // state while it reads the final value. Finalised in a `finally` so a
    // throwing callback cannot leave the gesture active and reject every later
    // press.
    try {
      getArgsRef().onDragEnd?.(event, dragInfo(event));
    } finally {
      finish();
    }
  };

  const onPointerCancel = (event: PointerEvent) => {
    if (pointerId === null || event.pointerId !== pointerId) {
      return;
    }
    cancelGesture(getArgsRef(), event);
  };

  /**
   * Refuses native drag-and-drop while a gesture is live, which the cancelled
   * press would otherwise have done.
   */
  const onNativeDragStart = (event: DragEvent) => {
    if (pointerId !== null) {
      event.preventDefault();
    }
  };

  const onLostPointerCapture = (event: PointerEvent) => {
    if (pointerId === null || event.pointerId !== pointerId) {
      return;
    }
    const activeCaptureWasLost =
      event.target === capturedNode || event.target === document;
    if (!activeCaptureWasLost) {
      return;
    }
    // Once capture is gone, a pointer no longer over this element delivers its
    // release somewhere else, so this is the last event to arrive and a gesture
    // not ended here stays in flight forever. A normal release fires this too,
    // but after `pointerup` cleared the state, so the guard above no-ops it.
    cancelGesture(getArgsRef(), event);
  };

  // `touch-action` has to be in effect before the gesture starts, or the browser
  // has already claimed the touch as a scroll. Expressed as an attribute the
  // stylesheet maps, rather than an inline style, because consumers bind `style`
  // and would clobber it. Refreshed by `syncTouchAction` so a consumer that
  // changes orientation between gestures is not stuck with the first value.
  syncTouchAction(element, getArgsRef().touchAction);

  element.addEventListener("dragstart", onNativeDragStart);
  element.addEventListener("pointerdown", onPointerDown);
  element.addEventListener("pointermove", onPointerMove);
  element.addEventListener("pointerup", onPointerUp);
  element.addEventListener("pointercancel", onPointerCancel);
  element.addEventListener("lostpointercapture", onLostPointerCapture);

  return () => {
    tornDown = true;
    finish();
    unwatchDocumentLoss();
    element.removeEventListener("dragstart", onNativeDragStart);
    element.removeEventListener("pointerdown", onPointerDown);
    element.removeEventListener("pointermove", onPointerMove);
    element.removeEventListener("pointerup", onPointerUp);
    element.removeEventListener("pointercancel", onPointerCancel);
    element.removeEventListener("lostpointercapture", onLostPointerCapture);
    element.removeAttribute("data-pointer-drag");
  };
}

/**
 * Binds the press-drag-transform gesture to an element. Thin Ember-modifier
 * wrapper around {@link registerPointerDrag}. Every arg is optional and
 * documented on {@link DPointerDragArgs}.
 *
 * @example
 * ```gjs
 * <span {{dPointerDrag
 *   onDragStart=this.onDragStart
 *   onDrag=this.onDrag
 *   onDragEnd=this.onDragEnd
 *   onDragCancel=this.onDragCancel
 *   draggingClass="--dragging"
 * }} />
 * ```
 *
 * A press never moves focus. Cancelling `pointerdown` suppresses the compatibility
 * `mousedown` that focus rides on, and that suppression is kept: a handle usually
 * sits beside the thing it resizes or reorders, so taking focus on press would pull
 * the caret out of whatever the user was working in. Give the handle its own tab
 * stop when it has a keyboard path worth reaching — that is how it stays operable,
 * not by claiming focus from a gesture assistive technology cannot perform.
 *
 * That cancellation reaches further than focus: an accepted press produces no
 * `mousedown` or `mouseup`, so a document-level listener on either never sees it.
 * Build dismiss-on-outside-press on `pointerdown`, which still bubbles unless
 * `stopPropagation` is set.
 *
 * A single element supports one registration. Two would each claim the same
 * pointer capture and the same attribute, and tearing either down would strand
 * the other's gesture.
 *
 * Nesting one registration inside another is supported, but only one of them can
 * hold a given press: the ancestor sees it too, and whichever claims the pointer
 * last keeps it. The other is ended immediately through `onDragCancel` (or
 * `onDragEnd` under `cancelCommits`) with the same press as its event, so a
 * contested press still leaves each consumer with one terminal callback for the
 * `onDragStart` it received. Pass `stopPropagation` on the inner registration when
 * the press should not reach the ancestor at all.
 *
 * The one end that reports nothing is teardown: destroying the element mid-gesture
 * releases the capture and drops the classes but fires no terminal callback, since
 * one would run against a consumer already being torn down. Release gesture state
 * that outlives the handle from the consumer's own destructor instead.
 */
export default class DPointerDragModifier extends Modifier<DPointerDragSignature> {
  #args: DPointerDragArgs | null = null;
  #cleanup: (() => void) | null = null;

  constructor(owner: Owner, args: ArgsFor<DPointerDragSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#teardown());
  }

  modify(element: HTMLElement, _positional: [], named: DPointerDragArgs) {
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
