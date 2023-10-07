import { isTesting } from "discourse-common/config/environment";

/**
   Swipe events is a class that allows components to detect and respond to swipe gestures
   It sets up custom events for swipestart, swipeend, and swipe for beginning swipe, end swipe, and during swipe. Event returns detail.state with swipe state, and the original event..
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
    this.addTouchListeners();
  }

  addTouchListeners() {
    this.touchStart = (e) => e.touches && this.#swipeStart(e.touches[0]);
    this.touchMove = (e) => {
      const touchEvent = e.touches[0];
      touchEvent.type = "pointermove";
      this.#swipeMove(touchEvent, e);
    };
    this.touchEnd = (e) => this.#swipeMove({ type: "pointerup" }, e);
    this.touchCancel = (e) => this.#swipeMove({ type: "pointercancel" }, e);

    const opts = {
      passive: false,
    };
    this.element.addEventListener("touchstart", this.touchStart, opts);
    this.element.addEventListener("touchmove", this.touchMove, opts);
    this.element.addEventListener("touchend", this.touchEnd, opts);
    this.element.addEventListener("touchcancel", this.touchCancel, opts);
  }

  // Remove touch listeners to be called by client on destory
  removeTouchListeners() {
    this.element.removeEventListener("touchstart", this.touchStart);
    this.element.removeEventListener("touchmove", this.touchMove);
    this.element.removeEventListener("touchend", this.touchEnd);
    this.element.removeEventListener("touchcancel", this.touchCancel);
  }

  // common max animation time in ms for swipe events for swipe end
  // prefers reduced motion and tests return 0
  getMaxAnimationTimeMs(durationMs = MAX_ANIMATION_TIME) {
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
  shouldCloseMenu(e, origin) {
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

  isSwipingRight(e) {
    return (
      (e.detail.deltaX > SWIPE_DISTANCE_THRESHOLD &&
        e.detail.velocityX > -SWIPE_VELOCITY_THRESHOLD) ||
      e.detail.velocityX > 0
    );
  }
  isSwipingLeft(e) {
    return (
      (e.detail.deltaX < -SWIPE_DISTANCE_THRESHOLD &&
        e.detail.velocityX < SWIPE_VELOCITY_THRESHOLD) ||
      e.detail.velocityX < 0
    );
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

    return {
      startLocation: oldState.startLocation,
      center: { x: e.clientX, y: e.clientY },
      velocityX,
      velocityY,
      deltaX,
      deltaY,
      start: false,
      timestamp: newTimestamp,
      direction: this.#calculateDirection(oldState, deltaX, deltaY),
    };
  }

  #swipeStart(e) {
    const newState = {
      center: { x: e.clientX, y: e.clientY },
      startLocation: { x: e.clientX, y: e.clientY },
      velocityX: 0,
      velocityY: 0,
      deltaX: 0,
      deltaY: 0,
      start: true,
      timestamp: Date.now(),
      direction: null,
    };
    this.swipeState = newState;
  }

  #swipeMove(e, originalEvent) {
    if (!this.swipeState) {
      this.#swipeStart(e);
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
      const event = new CustomEvent("swipestart", { detail: newState });
      this.element.dispatchEvent(event);
    } else if (e.type === "pointerup" || e.type === "pointercancel") {
      const event = new CustomEvent("swipeend", { detail: newState });
      this.element.dispatchEvent(event);
    } else if (e.type === "pointermove") {
      if (this.animationPending) {
        return;
      }
      this.animationPending = true;
      window.requestAnimationFrame(() => {
        if (!this.animationPending) {
          return;
        }
        const event = new CustomEvent("swipe", { detail: newState });
        this.element.dispatchEvent(event);
        this.animationPending = false;
      });
    }
  }
}
