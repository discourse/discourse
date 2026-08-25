import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";

let animationTimeOverride = null;

export function overrideAnimationTimeForTesting(durationMs = null) {
  animationTimeOverride = durationMs;
}

// common max animation time in ms for swipe events for swipe end
// prefers reduced motion and tests return 0
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
        detail: { originalEvent: e },
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
          detail: { originalEvent: e },
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
    let velocityX = elapsed > 0 ? movedX / elapsed : 0;
    let velocityY = elapsed > 0 ? movedY / elapsed : 0;
    if (
      e.type === "pointerup" &&
      movedX === 0 &&
      movedY === 0 &&
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
