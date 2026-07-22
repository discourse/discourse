import { registerDestructor } from "@ember/destroyable";
import { cancel, throttle } from "@ember/runloop";
import Modifier from "ember-modifier";

const THROTTLE_RATE = 20;

// How far a single arrow key press moves the edge, in pixels.
const KEYBOARD_STEP = 16;

/**
 * Makes an element behave as a draggable edge that resizes something along the
 * horizontal axis, following the WAI-ARIA window splitter pattern.
 *
 * The modifier owns the interaction only. It reports the size it computed and
 * leaves storing and applying it to the caller, so that the same element can
 * drive a width held in a component, a service, or a CSS custom property.
 *
 * Both pointer and keyboard interaction are supported, which is what the
 * splitter pattern requires: a resize that can only be performed by dragging
 * is unusable without a pointing device.
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
 *
 * @param {number} value - The current size, in pixels.
 * @param {number} min - The smallest size the edge may be dragged to.
 * @param {number} max - The largest size the edge may be dragged to.
 * @param {"start"|"end"} [side="start"] - Which edge the resized element is
 *   docked against, in logical terms. Combined with the writing direction this
 *   decides whether moving the pointer right makes it larger or smaller.
 * @param {(size: number) => void} [onResize] - Called continuously while
 *   dragging, throttled. Suitable for updating the rendered size.
 * @param {(size: number) => void} [onResizeEnd] - Called once when the
 *   interaction finishes. Suitable for persisting the size.
 */
export default class DResizeEdgeModifier extends Modifier {
  #onPointerDown = (event) => {
    // Ignore anything that is not a primary button press, so that a right
    // click or a secondary pointer cannot begin a resize.
    if (event.button !== 0) {
      return;
    }

    // A drag is already in progress. Taking this one over would overwrite the
    // tracked pointer and strand the first one's capture, since its release
    // would then no longer match.
    if (this.#pointerId !== null) {
      return;
    }

    event.preventDefault();

    this.#pointerId = event.pointerId;
    this.#startCoordinate = event.clientX;
    this.#startValue = this.named.value;

    this.#element.setPointerCapture(event.pointerId);
    this.#element.addEventListener("pointermove", this.#onPointerMove);
    this.#element.addEventListener("pointerup", this.#onPointerUp);
    this.#element.addEventListener("pointercancel", this.#onPointerUp);
  };
  #onPointerMove = (event) => {
    if (event.pointerId !== this.#pointerId) {
      return;
    }

    // Throttled because a pointer move fires far more often than a size change
    // can usefully be rendered.
    this.#throttled = throttle(
      this,
      this.#reportMove,
      event.clientX,
      THROTTLE_RATE
    );
  };
  #onPointerUp = (event) => {
    if (event.pointerId !== this.#pointerId) {
      return;
    }

    cancel(this.#throttled);
    this.#reportMove(event.clientX, { final: true });
    this.#releasePointer();
  };
  #onKeyDown = (event) => {
    const { value, min, max } = this.named;
    let next;

    switch (event.key) {
      case "ArrowLeft":
        next = value - KEYBOARD_STEP * this.#growthDirection;
        break;
      case "ArrowRight":
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
    this.named.onResize?.(clamped);
    this.named.onResizeEnd?.(clamped);
  };
  #element;
  #pointerId = null;
  #startCoordinate = 0;
  #startValue = 0;
  #throttled;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, _positional, named) {
    this.#element = element;
    this.named = named;

    element.addEventListener("pointerdown", this.#onPointerDown);
    element.addEventListener("keydown", this.#onKeyDown);
  }

  cleanup() {
    cancel(this.#throttled);

    this.#element.removeEventListener("pointerdown", this.#onPointerDown);
    this.#element.removeEventListener("keydown", this.#onKeyDown);
    this.#releasePointer();
  }

  /**
   * The multiplier turning pointer movement into a size change.
   *
   * An element docked to the inline start grows as the pointer moves away from
   * that edge. Which physical direction that is depends on the writing
   * direction, so `side` is interpreted logically and flipped under RTL —
   * otherwise the edge would move away from the pointer dragging it.
   *
   * @returns {number} Either 1 or -1.
   */
  get #growthDirection() {
    const logical = this.named.side === "end" ? -1 : 1;
    const rtl = getComputedStyle(this.#element).direction === "rtl";

    return logical * (rtl ? -1 : 1);
  }

  #reportMove(clientX, { final = false } = {}) {
    const delta = (clientX - this.#startCoordinate) * this.#growthDirection;
    const size = this.#clamp(this.#startValue + delta);

    this.named.onResize?.(size);

    if (final) {
      this.named.onResizeEnd?.(size);
    }
  }

  #clamp(size) {
    return Math.min(Math.max(size, this.named.min), this.named.max);
  }

  #releasePointer() {
    if (this.#pointerId === null) {
      return;
    }

    if (this.#element.hasPointerCapture(this.#pointerId)) {
      this.#element.releasePointerCapture(this.#pointerId);
    }

    this.#element.removeEventListener("pointermove", this.#onPointerMove);
    this.#element.removeEventListener("pointerup", this.#onPointerUp);
    this.#element.removeEventListener("pointercancel", this.#onPointerUp);
    this.#pointerId = null;
  }
}
