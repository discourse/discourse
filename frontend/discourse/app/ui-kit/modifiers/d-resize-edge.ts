import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";
import {
  type DPointerDragArgs,
  registerPointerDrag,
} from "discourse/ui-kit/modifiers/d-pointer-drag";

/** How far a single arrow key press moves the edge, in pixels. */
const KEYBOARD_STEP = 16;

/**
 * What produced a size report. A consumer that mirrors the size for assistive
 * technology needs this: a held arrow key is one gesture spanning every repeat,
 * so waiting for the commit would leave the announced value stale for as long as
 * the key is down, where a pointer gesture reports through a frame and settles
 * on release.
 */
export interface ResizeReportMeta {
  source: "pointer" | "keyboard";
}

interface DResizeEdgeSignature {
  /** The element acting as the edge. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * The current size, in pixels, or a function returning it. Read once at the
       * start of each gesture — a press, or the first of a run of key repeats —
       * and never again while one is in flight.
       *
       * A measurement may return `null` to say it has nothing yet. There is no
       * size to resize *from* in that state, so the gesture is refused rather
       * than started from an assumed zero.
       */
      value: number | null | (() => number | null);

      /**
       * The smallest size the edge may be dragged to, or a function returning it.
       * Read every time a size is clamped.
       */
      min: number | (() => number);

      /**
       * The largest size the edge may be dragged to, or a function returning it.
       * Read every time a size is clamped.
       */
      max: number | (() => number);

      /**
       * The axis the edge moves along. Defaults to `"horizontal"`.
       *
       * Note that this is the opposite of the `aria-orientation` the element
       * should carry: that describes the separator itself, which lies across
       * the axis it moves along.
       */
      axis?: "horizontal" | "vertical";

      /**
       * Which edge the resized element is docked against, in logical terms.
       * Combined with the writing direction this decides whether moving the
       * pointer away from that edge makes it larger or smaller. Defaults to
       * `"start"`.
       *
       * Read live, unlike `value`, which is frozen for the length of a gesture.
       * Changing this or `axis` mid-gesture measures the new orientation against
       * an origin captured in the old one, so the result is undefined.
       */
      side?: "start" | "end";

      /**
       * A class held on `document.body` for the length of a gesture, for a cursor
       * that has to survive the pointer leaving the edge. Whether the cursor of the
       * element a drag began on does that by itself is engine-dependent, so it
       * cannot be left to the edge's own rule.
       */
      bodyClass?: string;

      /**
       * Called once when a resize begins, immediately before the first size is
       * reported. Purely a notification — the return value is ignored, and a
       * caller whose size is a live measurement supplies it by passing a
       * function as `value`.
       *
       * Fires on the first report rather than on the press, so a press that
       * never becomes a resize opens nothing. Anything held for the length of
       * the gesture belongs here, because it is always closed by exactly one
       * `onResizeEnd`.
       */
      onResizeStart?: () => void;

      /**
       * Called while the size is changing: at most once per animation frame while
       * dragging, and once per key press or repeat. Suitable for updating the
       * rendered size.
       */
      onResize?: (size: number, meta: ResizeReportMeta) => void;

      /**
       * Called once when the gesture finishes. Suitable for work that should
       * happen once per resize rather than once per report — persisting the
       * size, or undoing something held for the length of the gesture.
       *
       * Every one of these is preceded by exactly one `onResizeStart`, and a
       * gesture that reported no size fires neither: a press released without
       * moving is a click rather than a resize, and opens nothing.
       *
       * The converse does not hold. Teardown mid-gesture fires no consumer
       * callback at all, so a gesture that had reported and is then torn down
       * leaves its `onResizeStart` unclosed. State held for the length of a
       * resize therefore has to be released on the consumer's own destruction
       * too, not on this alone.
       */
      onResizeEnd?: (size: number, meta: ResizeReportMeta) => void;
    };
    Positional: [];
  };
}

/**
 * Makes an element behave as a draggable edge that resizes something along one
 * axis, following the WAI-ARIA window splitter pattern.
 *
 * The modifier owns the interaction only. It reports the size it computed and
 * leaves storing and applying it to the caller, so that the same element can
 * drive a width held in a component, a service, or a CSS custom property. The
 * reported number carries no unit of its own: it is whatever `value`, `min`,
 * and `max` are expressed in, which is a width for a side panel but an offset
 * from a resting height for a composer.
 *
 * `value`, `min` and `max` may each be a function instead of a number, which is
 * what a caller whose size or bounds are a live measurement of the DOM or the
 * window must use — see `#read`.
 *
 * Both pointer and keyboard interaction are supported, which is what the
 * splitter pattern requires: a resize that can only be performed by dragging
 * is unusable without a pointing device. The pointer half is delegated to
 * `registerPointerDrag`, the shared press-drag-transform engine, which covers
 * mouse, touch and pen alike and marks the element so that a touch drag is not
 * claimed by the browser as a scroll gesture. This modifier keeps the value
 * semantics: clamping, the logical `side` handling, and the keyboard path.
 *
 * Both halves report the same shape — one `onResizeStart`, any number of
 * `onResize`, one `onResizeEnd` — so a caller can hold state for the length of a
 * resize without caring which input performed it. A held arrow key is therefore
 * one gesture rather than one per repeat, and its running size is kept here
 * instead of re-read from `value`: a caller whose size is a live measurement
 * cannot settle it between repeats, and stepping from a box still moving toward
 * the previous size would swallow most of each step.
 *
 * ```hbs
 * <div
 *   role="separator"
 *   aria-orientation="vertical"
 *   aria-valuenow={{this.width}}
 *   aria-valuemin={{this.minWidth}}
 *   aria-valuemax={{this.maxWidth}}
 *   tabindex="0"
 *   {{dResizeEdge
 *     value=this.width
 *     min=this.minWidth
 *     max=this.maxWidth
 *     side="start"
 *     bodyClass="d-resizing-ew"
 *     onResizeStart=this.suppressTransitions
 *     onResize=this.previewWidth
 *     onResizeEnd=this.commitWidth
 *   }}
 * ></div>
 * ```
 *
 * @see The `DResizeSeparator` component, which wraps this and supplies the whole block of
 *   separator markup above. Prefer it; reach for this modifier directly only when
 *   the element and its semantics are already yours to own.
 * @see `DResizeHandles` to resize a box in both directions. It is not a separator:
 *   a box has no single value to report as `aria-valuenow`.
 * @see The `dOnResize` modifier to merely OBSERVE a size change. It is not a gesture.
 */
export default class DResizeEdgeModifier extends Modifier<DResizeEdgeSignature> {
  /** The options from the most recent invocation, set by `modify`. */
  #named: DResizeEdgeSignature["Args"]["Named"];

  #onDragStart = (event: PointerEvent) => {
    // A pointer taking over closes any key still being held, so the two inputs
    // cannot leave two gestures open against a single end.
    this.#endKeyboardGesture();

    const startValue = this.#read(this.#named.value);
    if (!Number.isFinite(startValue)) {
      // Nothing to resize from. Vetoing hands the press back rather than
      // starting a gesture whose first report would be `null + delta` clamped
      // to a bound, which moves the box somewhere nobody dragged it.
      return false;
    }

    this.#pointerActive = true;
    this.#rtl = undefined;
    this.#started = false;
    this.#startCoordinate = this.#coordinate(event);
    // Reset so a cancellation before any movement reads the origin, not the
    // previous gesture's last position.
    this.#pendingCoordinate = this.#startCoordinate;
    this.#startValue = startValue;
  };
  #onDrag = (event: PointerEvent) => {
    // A pointer can move several times between paints, so only the latest
    // position is kept and reported on the next frame. A size computed for the
    // positions in between would be replaced before anything rendered it.
    this.#pendingCoordinate = this.#coordinate(event);
    this.#frame ??= requestAnimationFrame(() => {
      this.#frame = undefined;
      this.#reportMove(this.#pendingCoordinate);
    });
  };
  #onDragEnd = (event: PointerEvent) => {
    // The committed size is the one the pointer was released at, so any frame
    // still pending is dropped first: letting it fire afterwards would report a
    // stale intermediate size over the committed one.
    this.#cancelFrame();
    this.#pointerActive = false;

    // A cancellation's own coordinates are not the pointer's last position —
    // A cancelled pointer event may carry (0,0), while a browser-fired
    // `lostpointercapture` carries no meaningful position either — so the
    // commit falls back to the last position the pointer actually reached.
    // Recomputing from the event would snap the size to a clamp bound.
    const cancelled =
      event.type === "pointercancel" || event.type === "lostpointercapture";
    const coordinate = cancelled
      ? this.#pendingCoordinate
      : this.#coordinate(event);
    // A press that reported nothing and was released where it landed is a click,
    // not a resize. Reporting it would hand the consumer the size it already
    // had, which is enough to make it persist one. The coordinate is checked as
    // well as `#started` because a browser may coalesce a short drag into no
    // intermediate pointer move, and that is still a resize.
    //
    // A gesture that DID report is always closed, whatever the release
    // coordinate: a drag that returned to its origin, or one along the other
    // axis, has already told the consumer a resize was under way.
    if (!this.#started && coordinate === this.#startCoordinate) {
      return;
    }
    this.#reportMove(coordinate, { final: true });
  };
  #onKeyDown = (event: KeyboardEvent) => {
    // The mirror of the pointer closing a held key: a key must not open a second
    // gesture over a drag in flight either, or its release would report the
    // resize ended while the pointer is still dragging.
    if (this.#pointerActive) {
      return;
    }

    // A modified arrow belongs to whatever binding claims it — back, word-wise
    // motion, selection — and the separator merely happens to hold focus. The
    // window-splitter pattern defines no modified bindings of its own.
    if (event.ctrlKey || event.metaKey || event.altKey || event.shiftKey) {
      return;
    }

    const [shrinkKey, growKey] =
      this.#named.axis === "vertical"
        ? ["ArrowUp", "ArrowDown"]
        : ["ArrowLeft", "ArrowRight"];

    if (![shrinkKey, growKey, "Home", "End"].includes(event.key)) {
      return;
    }

    if (this.#keyboardValue === null) {
      const startValue = this.#read(this.#named.value);
      // Checked before the key is claimed: with no size to step from there is
      // nothing to handle, so the key belongs to whatever else would act on it.
      if (!Number.isFinite(startValue)) {
        return;
      }

      event.preventDefault();
      this.#rtl = undefined;
      this.#keyboardValue = startValue;
      this.#keyboardKey = event.key;
      this.#named.onResizeStart?.();
    } else {
      event.preventDefault();
    }

    let next;

    switch (event.key) {
      case shrinkKey:
        next = this.#keyboardValue - KEYBOARD_STEP * this.#growthDirection;
        break;
      case growKey:
        next = this.#keyboardValue + KEYBOARD_STEP * this.#growthDirection;
        break;
      case "Home":
        next = this.#read(this.#named.min);
        break;
      default:
        next = this.#read(this.#named.max);
        break;
    }

    this.#keyboardValue = this.#clamp(next);
    this.#named.onResize?.(this.#keyboardValue, { source: "keyboard" });
  };
  #onKeyUp = (event: KeyboardEvent) => {
    if (event.key !== this.#keyboardKey) {
      return;
    }

    this.#endKeyboardGesture();
  };
  /**
   * The keyup would land on whatever took focus, so without this the gesture
   * would stay open and never commit. Bound to the window as well as the
   * element: focus leaving the page entirely, or the page being replaced, takes
   * the keyup with it without the element ever seeing a blur.
   */
  #onBlur = () => this.#endKeyboardGesture();
  #element: HTMLElement;
  #frame?: number;

  /** The key holding the current keyboard gesture open, if any. */
  #keyboardKey: string | null = null;

  /**
   * The running size of the current keyboard gesture, or `null` when no key is
   * down. Held rather than re-read from `value` on each repeat, for the reason
   * given on the class.
   */
  #keyboardValue: number | null = null;

  #pendingCoordinate = 0;

  /**
   * Whether a pointer gesture is in flight, which locks the keyboard path out
   * for its duration.
   */
  #pointerActive = false;

  #releaseGesture: (() => void) | null = null;

  /**
   * Whether the element reads right-to-left, sampled on the first read within
   * the current gesture. Cleared at the start of each one so a document that
   * changed direction in between is measured again.
   */
  #rtl?: boolean;

  #startCoordinate = 0;

  /**
   * Whether the pointer gesture in flight has reported a size, and so whether
   * `onResizeStart` has been fired and is owed an `onResizeEnd`.
   */
  #started = false;

  #startValue = 0;

  /**
   * The gesture args handed to `registerPointerDrag`. Typed from the engine's own
   * args rather than restated, so narrowing one of them cannot leave this behind.
   */
  #gestureArgs: DPointerDragArgs;

  constructor(owner: Owner, args: ArgsFor<DResizeEdgeSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element: HTMLElement,
    _positional: [],
    named: DResizeEdgeSignature["Args"]["Named"]
  ) {
    this.#element = element;
    this.#named = named;

    this.#gestureArgs = {
      onDragStart: this.#onDragStart,
      onDrag: this.#onDrag,
      onDragEnd: this.#onDragEnd,
      // An OS-interrupted resize keeps the size the user dragged to rather than
      // snapping back, so cancellation commits.
      cancelCommits: true,
      // A touch drag would otherwise be claimed by the browser as a scroll and
      // abort the resize through `pointercancel`. An edge is small enough that
      // suppressing every touch gesture on it costs the user nothing.
      touchAction: "none",
      bodyClass: named.bodyClass,
    };

    // The gesture engine owns pointer identity, capture, and the primary-button
    // gate; this modifier keeps the value semantics and the keyboard path.
    this.#releaseGesture ??= registerPointerDrag(
      element,
      () => this.#gestureArgs
    );

    element.addEventListener("keydown", this.#onKeyDown);
    element.addEventListener("keyup", this.#onKeyUp);
    element.addEventListener("blur", this.#onBlur);
    window.addEventListener("blur", this.#onBlur);
    window.addEventListener("pagehide", this.#onBlur);
  }

  cleanup() {
    this.#cancelFrame();

    this.#releaseGesture?.();
    this.#releaseGesture = null;
    // Dropped rather than committed: the element is going away, so a caller
    // undoing gesture state has nothing left to undo it on.
    this.#keyboardKey = null;
    this.#keyboardValue = null;
    this.#pointerActive = false;
    this.#element?.removeEventListener("keydown", this.#onKeyDown);
    this.#element?.removeEventListener("keyup", this.#onKeyUp);
    this.#element?.removeEventListener("blur", this.#onBlur);
    window.removeEventListener("blur", this.#onBlur);
    window.removeEventListener("pagehide", this.#onBlur);
  }

  /**
   * The multiplier turning pointer movement into a size change.
   *
   * An element docked to the start of the axis grows as the pointer moves away
   * from that edge. On the horizontal axis which physical direction that is
   * depends on the writing direction, so `side` is interpreted logically and
   * flipped under RTL — otherwise the edge would move away from the pointer
   * dragging it. The vertical axis is unaffected: RTL reverses the inline axis
   * only.
   *
   * @returns Either 1 or -1.
   */
  get #growthDirection() {
    const logical = this.#named.side === "end" ? -1 : 1;

    if (this.#named.axis === "vertical") {
      return logical;
    }

    // Sampled once per gesture rather than on every read: this runs for each
    // reported frame, and the consumer is changing sizes in that same frame, so
    // every read forces a style recalculation. `side` and `axis` above stay live
    // reads — only the writing direction is held, and it is not something that
    // changes while a pointer is down.
    this.#rtl ??= getComputedStyle(this.#element).direction === "rtl";

    return logical * (this.#rtl ? -1 : 1);
  }

  /**
   * The pointer position along the axis being resized.
   *
   * @returns The client coordinate, in pixels.
   */
  #coordinate(event: PointerEvent) {
    return this.#named.axis === "vertical" ? event.clientY : event.clientX;
  }

  #reportMove(coordinate: number, { final = false }: { final?: boolean } = {}) {
    const delta = (coordinate - this.#startCoordinate) * this.#growthDirection;
    const size = this.#clamp(this.#startValue + delta);

    // Opened on the first report rather than on the press, so a press that never
    // becomes a resize opens nothing and needs nothing closed. A consumer that
    // suppresses transitions or announces a resize for the length of the gesture
    // would otherwise be left holding that state after a plain click.
    if (!this.#started) {
      this.#started = true;
      this.#named.onResizeStart?.();
    }

    this.#named.onResize?.(size, { source: "pointer" });

    if (final) {
      this.#named.onResizeEnd?.(size, { source: "pointer" });
    }
  }

  /**
   * Commits the keyboard gesture currently open, if there is one.
   *
   * The state is cleared before the callback runs, so a caller that opens another
   * gesture from it does not find this one still standing.
   */
  #endKeyboardGesture() {
    if (this.#keyboardValue === null) {
      return;
    }

    const size = this.#keyboardValue;

    this.#keyboardKey = null;
    this.#keyboardValue = null;
    this.#named.onResizeEnd?.(size, { source: "keyboard" });
  }

  /**
   * Resolves a size arg that may be given as a function.
   *
   * A caller whose size or bounds are a live measurement of the DOM or the window
   * has to pass a function: an arg whose compute reads no tracked state is cached
   * for the modifier's lifetime, so a plain number would be frozen at its first
   * value and every later gesture would work from a stale one.
   *
   * @param arg - A size, or a function returning one.
   * @returns The size in pixels.
   */
  #read(arg: number | (() => number)) {
    return typeof arg === "function" ? arg() : arg;
  }

  #clamp(size: number) {
    // The minimum is applied last, so it wins when the two bounds conflict — a
    // short viewport can put `max` below `min`, and the stylesheet's own min-height
    // would still hold the box open. Letting `max` win would report a size the
    // element never takes.
    return Math.max(
      Math.min(size, this.#read(this.#named.max)),
      this.#read(this.#named.min)
    );
  }

  #cancelFrame() {
    if (this.#frame === undefined) {
      return;
    }

    cancelAnimationFrame(this.#frame);
    this.#frame = undefined;
  }
}
