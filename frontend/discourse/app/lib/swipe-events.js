import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";

let animationTimeOverride = null;

export function overrideAnimationTimeForTesting(durationMs = null) {
  animationTimeOverride = durationMs;
}

// Common max animation time in ms for a swipe's release. Reduced motion and
// tests collapse it to 0, or to whatever a test asked for.
export function getMaxAnimationTimeMs(durationMs = MAX_ANIMATION_TIME) {
  if (
    isTesting() ||
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  ) {
    return animationTimeOverride ?? 0;
  }
  return Math.min(durationMs, MAX_ANIMATION_TIME);
}

//functions to calculate if a swipe should close
//based on origin of right, left, top, bottom
// menu should close after a swipe either:
// if a user moved the panel closed past a threshold and away and is NOT swiping back open
// if a user swiped to close fast enough regardless of distance
export function shouldCloseMenu(e, origin) {
  if (origin === "right") {
    return (
      (e.deltaX > SWIPE_DISTANCE_THRESHOLD &&
        e.velocityX > -SWIPE_VELOCITY_THRESHOLD) ||
      e.velocityX > 0
    );
  } else if (origin === "left") {
    return (
      (e.deltaX < -SWIPE_DISTANCE_THRESHOLD &&
        e.velocityX < SWIPE_VELOCITY_THRESHOLD) ||
      e.velocityX < 0
    );
  } else if (origin === "bottom") {
    return (
      (e.deltaY > SWIPE_DISTANCE_THRESHOLD &&
        e.velocityY > -SWIPE_VELOCITY_THRESHOLD) ||
      e.velocityY > 0
    );
  } else if (origin === "top") {
    return (
      (e.deltaY < -SWIPE_DISTANCE_THRESHOLD &&
        e.velocityY < SWIPE_VELOCITY_THRESHOLD) ||
      e.velocityY < 0
    );
  }
  return false;
}

export function dampenedOverdrag(distance) {
  return Math.max(0, 8 * (Math.log(distance + 1) - 2));
}

export function shouldDeferSwipeToContent(swipeState, container) {
  if (swipeState.direction === "left" || swipeState.direction === "right") {
    return true;
  }

  let element = swipeState.originalEvent?.target;

  while (element && element !== container) {
    if (element.scrollHeight > element.clientHeight) {
      const style = window.getComputedStyle(element);

      if (style.overflowY === "auto" || style.overflowY === "scroll") {
        // column-reverse scrollers rest at scrollTop 0 and go negative when
        // scrolled back, so normalize scrollTop to a distance from the top
        // edge before checking for remaining room
        const maxScroll = element.scrollHeight - element.clientHeight;
        const reversed =
          style.display.includes("flex") &&
          style.flexDirection === "column-reverse";
        const distanceFromTop = reversed
          ? maxScroll + element.scrollTop
          : element.scrollTop;

        if (swipeState.direction === "down" && distanceFromTop > 0) {
          return true;
        }

        if (swipeState.direction === "up" && distanceFromTop < maxScroll) {
          return true;
        }
      }
    }

    element = element.parentElement;
  }

  return false;
}

export const SWIPE_DISTANCE_THRESHOLD = 50;
export const SWIPE_VELOCITY_THRESHOLD = 0.12;
export const MINIMUM_SWIPE_DISTANCE = 5;
export const MAX_ANIMATION_TIME = 200;
const SWIPE_VELOCITY_EXPIRY_MS = 100;
// A release trails the last move by a frame or two. A pixel or two across that
// sliver is the finger lifting, so it neither reads as a flick of its own nor
// discards the flick that came before it.
const SWIPE_VELOCITY_STILL_PX = 2;
const SWIPE_VELOCITY_MIN_INTERVAL_MS = 16;

/**
 * Turns touch events on an element into `swipestart`, `swipe`, `swipeend` and
 * `swipecancel`, each carrying the gesture's state as `detail`.
 *
 * `swipestart` is cancelable: `preventDefault()` on it refuses the gesture, and
 * nothing further is dispatched until the next one. `swipecancel` fires when the
 * gesture is taken away — a second touch, or the browser claiming it — so a
 * consumer that painted anything has to undo it there rather than in `swipeend`.
 */
export default class SwipeEvents {
  swipeState = null;
  animationPending = false;

  constructor(element) {
    this.element = element;
  }

  @bind
  touchStart(e) {
    if (e.touches.length > 1) {
      if (this.cancelled) {
        return;
      }
      this.cancelled = true;
      this.swiping = false;
      this.swipeState = null;
      const event = new CustomEvent("swipecancel", {
        detail: { originalEvent: e, element: this.element },
      });
      this.element.dispatchEvent(event);
      return;
    }
    this.swipeState = this.#swipeStart(e.touches[0], e.timeStamp);
  }

  @bind
  touchMove(e) {
    const touchEvent = e.touches[0];
    touchEvent.type = "pointermove";
    this.#swipeMove(touchEvent, e);
  }

  @bind
  touchEnd(e) {
    const touch = e.changedTouches[0] ?? this.swipeState?.center;
    if (touch) {
      this.#swipeMove(
        { clientX: touch.clientX, clientY: touch.clientY, type: "pointerup" },
        e
      );
    }
    if (e.touches.length === 0) {
      this.cancelled = false;
      this.swipeState = null;
    }
  }

  @bind
  touchCancel(e) {
    if (this.swipeState) {
      this.element.dispatchEvent(
        new CustomEvent("swipecancel", {
          detail: { originalEvent: e, element: this.element },
        })
      );
    }
    this.swiping = false;
    this.swipeState = null;
    if (e.touches.length === 0) {
      this.cancelled = false;
    }
  }

  addTouchListeners() {
    const opts = { passive: false };

    this.element.addEventListener("touchstart", this.touchStart, opts);
    this.element.addEventListener("touchmove", this.touchMove, opts);
    this.element.addEventListener("touchend", this.touchEnd, opts);
    this.element.addEventListener("touchcancel", this.touchCancel, opts);
  }

  removeTouchListeners() {
    this.element.removeEventListener("touchstart", this.touchStart);
    this.element.removeEventListener("touchmove", this.touchMove);
    this.element.removeEventListener("touchend", this.touchEnd);
    this.element.removeEventListener("touchcancel", this.touchCancel);
  }

  #calculateDirection(oldState, deltaX, deltaY) {
    if (oldState.start || !oldState.direction) {
      if (Math.abs(deltaX) > Math.abs(deltaY)) {
        return deltaX > 0 ? "right" : "left";
      } else {
        return deltaY > 0 ? "down" : "up";
      }
    }
    return oldState.direction;
  }

  #calculateNewSwipeState(oldState, e, timestamp) {
    const deltaX = e.clientX - oldState.startLocation.x;
    const deltaY = e.clientY - oldState.startLocation.y;
    const elapsed = timestamp - oldState.timestamp;
    const movedX = e.clientX - oldState.center.x;
    const movedY = e.clientY - oldState.center.y;
    const interval = Math.max(elapsed, SWIPE_VELOCITY_MIN_INTERVAL_MS);
    let velocityX = elapsed > 0 ? movedX / interval : 0;
    let velocityY = elapsed > 0 ? movedY / interval : 0;
    if (
      e.type === "pointerup" &&
      Math.abs(movedX) <= SWIPE_VELOCITY_STILL_PX &&
      Math.abs(movedY) <= SWIPE_VELOCITY_STILL_PX &&
      elapsed >= 0 &&
      elapsed <= SWIPE_VELOCITY_EXPIRY_MS
    ) {
      velocityX = oldState.velocityX;
      velocityY = oldState.velocityY;
    }
    if (e.type === "pointerup") {
      return {
        ...oldState,
        center: { x: e.clientX, y: e.clientY },
        deltaX,
        deltaY,
        start: false,
        velocityX,
        velocityY,
        timestamp,
      };
    }
    const direction = this.#calculateDirection(oldState, deltaX, deltaY);

    return {
      startLocation: oldState.startLocation,
      center: { x: e.clientX, y: e.clientY },
      velocityX,
      velocityY,
      deltaX,
      deltaY,
      start: false,
      timestamp,
      direction,
      element: this.element,
      goingUp: () => direction === "up",
      goingDown: () => direction === "down",
    };
  }

  #swipeStart(e, timestamp) {
    return {
      center: { x: e.clientX, y: e.clientY },
      startLocation: { x: e.clientX, y: e.clientY },
      velocityX: 0,
      velocityY: 0,
      deltaX: 0,
      deltaY: 0,
      start: true,
      timestamp,
      direction: null,
      element: this.element,
      goingUp: () => false,
      goingDown: () => false,
    };
  }

  #swipeMove(e, originalEvent) {
    if (this.cancelled) {
      return;
    }
    if (!this.swipeState) {
      this.swipeState = this.#swipeStart(e, originalEvent.timeStamp);
      return;
    }

    originalEvent.stopPropagation();
    const previousState = this.swipeState;
    const newState = this.#calculateNewSwipeState(
      previousState,
      e,
      originalEvent.timeStamp
    );
    const belowMinimum =
      Math.abs(newState.deltaX) < MINIMUM_SWIPE_DISTANCE &&
      Math.abs(newState.deltaY) < MINIMUM_SWIPE_DISTANCE;
    // A release now reports where the finger left, so its own delta can cross
    // the minimum. Only a move may open a gesture; otherwise a smear on lift
    // starts a swipe that nothing ever ends.
    if (previousState.start && (belowMinimum || e.type !== "pointermove")) {
      return;
    }
    this.swipeState = newState;
    newState.originalEvent = originalEvent;
    if (previousState.start) {
      const event = new CustomEvent("swipestart", {
        cancelable: true,
        detail: newState,
      });
      this.cancelled = !this.element.dispatchEvent(event);
      if (this.cancelled) {
        return;
      }
      this.swiping = true;
    } else if (
      (e.type === "pointerup" || e.type === "pointercancel") &&
      this.swiping
    ) {
      this.swiping = false;
      const event = new CustomEvent("swipeend", { detail: newState });
      this.element.dispatchEvent(event);
    } else if (e.type === "pointermove") {
      if (this.animationPending) {
        return;
      }
      this.animationPending = true;
      window.requestAnimationFrame(() => {
        if (!this.animationPending || !this.swiping || this.cancelled) {
          this.animationPending = false;
          return;
        }
        const event = new CustomEvent("swipe", { detail: newState });
        this.element.dispatchEvent(event);
        this.animationPending = false;
      });
    }
  }
}
