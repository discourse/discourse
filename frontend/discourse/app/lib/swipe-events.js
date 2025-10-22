import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";

// common max animation time in ms for swipe events for swipe end
// prefers reduced motion and tests return 0
export function getMaxAnimationTimeMs(durationMs = MAX_ANIMATION_TIME) {
  if (
    isTesting() ||
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  ) {
    return 0;
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

/**
   Swipe events is a class that allows components to detect and respond to swipe gestures
   It sets up custom events for swipestart, swipeend, and swipe for beginning swipe, end swipe, and during swipe. Event returns detail.state with swipe state, and the original event.

   Calling preventDefault() on the swipestart event stops swipe and swipeend events for the current gesture. it is re-enabled on future swipe events.
**/
export const SWIPE_DISTANCE_THRESHOLD = 50;
export const SWIPE_VELOCITY_THRESHOLD = 0.12;
export const MINIMUM_SWIPE_DISTANCE = 5;
export const MAX_ANIMATION_TIME = 200;

export default class SwipeEvents {
  //velocity is pixels per ms

  swipeState = null;
  animationPending = false;

  constructor(element) {
    this.element = element;
  }

  @bind
  touchStart(e) {
    // multitouch cancels current swipe event
    if (e.touches.length > 1) {
      if (this.cancelled) {
        return;
      }
      this.cancelled = true;
      const event = new CustomEvent("swipecancel", {
        detail: { originalEvent: e },
      });
      this.element.dispatchEvent(event);
      return;
    }
    this.swipeState = this.#swipeStart(e.touches[0]);
  }

  @bind
  touchMove(e) {
    const touchEvent = e.touches[0];
    touchEvent.type = "pointermove";
    this.#swipeMove(touchEvent, e);
  }

  @bind
  touchEnd(e) {
    this.#swipeMove({ type: "pointerup" }, e);
    // only reset when no touches remain
    if (e.touches.length === 0) {
      this.cancelled = false;
    }
  }

  @bind
  touchCancel(e) {
    this.#swipeMove({ type: "pointercancel" }, e);
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

  // Remove touch listeners to be called by client on destroy
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

  #calculateNewSwipeState(oldState, e) {
    if (e.type === "pointerup" || e.type === "pointercancel") {
      return oldState;
    }
    const newTimestamp = Date.now();
    const timeDiffSeconds = newTimestamp - oldState.timestamp;
    if (timeDiffSeconds === 0) {
      return oldState;
    }
    //calculate delta x, y from START location
    const deltaX = e.clientX - oldState.startLocation.x;
    const deltaY = e.clientY - oldState.startLocation.y;

    //calculate velocity from previous event center location
    const eventDeltaX = e.clientX - oldState.center.x;
    const eventDeltaY = e.clientY - oldState.center.y;
    const velocityX = eventDeltaX / timeDiffSeconds;
    const velocityY = eventDeltaY / timeDiffSeconds;
    const direction = this.#calculateDirection(oldState, deltaX, deltaY);

    return {
      startLocation: oldState.startLocation,
      center: { x: e.clientX, y: e.clientY },
      velocityX,
      velocityY,
      deltaX,
      deltaY,
      start: false,
      timestamp: newTimestamp,
      direction,
      element: this.element,
      goingUp: () => direction === "up",
      goingDown: () => direction === "down",
    };
  }

  #swipeStart(e) {
    return {
      center: { x: e.clientX, y: e.clientY },
      startLocation: { x: e.clientX, y: e.clientY },
      velocityX: 0,
      velocityY: 0,
      deltaX: 0,
      deltaY: 0,
      start: true,
      timestamp: Date.now(),
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
      this.swipeState = this.#swipeStart(e);
      return;
    }

    originalEvent.stopPropagation();
    const previousState = this.swipeState;
    const newState = this.#calculateNewSwipeState(previousState, e);
    if (
      previousState.start &&
      Math.abs(newState.deltaX) < MINIMUM_SWIPE_DISTANCE &&
      Math.abs(newState.deltaY) < MINIMUM_SWIPE_DISTANCE
    ) {
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
