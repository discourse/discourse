import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";
import { registerPointerDrag } from "discourse/ui-kit/modifiers/d-pointer-drag";

// How far a single arrow key press moves the edge, in pixels.
const KEYBOARD_STEP = 16;

interface DResizeEdgeSignature {
  /** The element acting as the edge. */
  Element: HTMLElement;
  Args: {
    Named: {
      /** The current size, in pixels. */
      value: number;

      /** The smallest size the edge may be dragged to. */
      min: number;

      /** The largest size the edge may be dragged to. */
      max: number;

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
       */
      side?: "start" | "end";

      /**
       * Called when a pointer gesture begins. Return the size the gesture should
       * start from to override `value` for this gesture; return nothing to use
       * `value` as usual. Anything non-finite is ignored.
       *
       * This exists for a caller whose current size is a live measurement of the
       * DOM or the window. Such a caller cannot supply it through `value`,
       * because an arg whose compute reads no tracked state is cached for the
       * modifier's lifetime, so every gesture after the first would start from
       * the first one's origin.
       */
      onResizeStart?: () => number | void;

      /**
       * Called while dragging, at most once per animation frame. Suitable for
       * updating the rendered size.
       */
      onResize?: (size: number) => void;

      /**
       * Called once when the interaction finishes. Suitable for persisting the
       * size.
       */
      onResizeEnd?: (size: number) => void;
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
 * Both pointer and keyboard interaction are supported, which is what the
 * splitter pattern requires: a resize that can only be performed by dragging
 * is unusable without a pointing device. The pointer half is delegated to
 * `registerPointerDrag`, the shared press-drag-transform engine, which covers
 * mouse, touch and pen alike and marks the element so that a touch drag is not
 * claimed by the browser as a scroll gesture. This modifier keeps the value
 * semantics: clamping, the logical `side` handling, and the keyboard path.
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
 *     onResize=this.previewWidth
 *     onResizeEnd=this.commitWidth
 *   }}
 * ></div>
 * ```
 */
export default class DResizeEdgeModifier extends Modifier<DResizeEdgeSignature> {
  /** The options from the most recent invocation, set by `modify`. */
  #named: DResizeEdgeSignature["Args"]["Named"];

  #onDragStart = (event: PointerEvent) => {
    this.#startCoordinate = this.#coordinate(event);

    const supplied = this.#named.onResizeStart?.();
    this.#startValue = Number.isFinite(supplied)
      ? (supplied as number)
      : this.#named.value;
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
    this.#reportMove(this.#coordinate(event), { final: true });
  };
  #onKeyDown = (event: KeyboardEvent) => {
    const { value, min, max } = this.#named;
    const [shrinkKey, growKey] =
      this.#named.axis === "vertical"
        ? ["ArrowUp", "ArrowDown"]
        : ["ArrowLeft", "ArrowRight"];
    let next;

    switch (event.key) {
      case shrinkKey:
        next = value - KEYBOARD_STEP * this.#growthDirection;
        break;
      case growKey:
        next = value + KEYBOARD_STEP * this.#growthDirection;
        break;
      case "Home":
        next = min;
        break;
      case "End":
        next = max;
        break;
      default:
        return;
    }

    event.preventDefault();

    const clamped = this.#clamp(next);
    this.#named.onResize?.(clamped);
    this.#named.onResizeEnd?.(clamped);
  };
  #element: HTMLElement;
  #frame?: number;
  #pendingCoordinate = 0;
  #releaseGesture: (() => void) | null = null;
  #startCoordinate = 0;
  #startValue = 0;
  /** The gesture args handed to `registerPointerDrag`. */
  #gestureArgs: {
    onDragStart: (event: PointerEvent) => void;
    onDrag: (event: PointerEvent) => void;
    onDragEnd: (event: PointerEvent) => void;
    cancelCommits: boolean;
    touchAction: string;
  };

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
    };

    // The gesture engine owns pointer identity, capture, and the primary-button
    // gate; this modifier keeps the value semantics and the keyboard path.
    this.#releaseGesture ??= registerPointerDrag(
      element,
      () => this.#gestureArgs
    );

    element.addEventListener("keydown", this.#onKeyDown);
  }

  cleanup() {
    this.#cancelFrame();

    this.#releaseGesture?.();
    this.#releaseGesture = null;
    this.#element.removeEventListener("keydown", this.#onKeyDown);
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

    const rtl = getComputedStyle(this.#element).direction === "rtl";

    return logical * (rtl ? -1 : 1);
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

    this.#named.onResize?.(size);

    if (final) {
      this.#named.onResizeEnd?.(size);
    }
  }

  #clamp(size: number) {
    return Math.min(Math.max(size, this.#named.min), this.#named.max);
  }

  #cancelFrame() {
    if (this.#frame === undefined) {
      return;
    }

    cancelAnimationFrame(this.#frame);
    this.#frame = undefined;
  }
}
