import Mixin from "@ember/object/mixin";
/**
   Pan events is a mixin that allows components to detect and respond to swipe gestures
   It fires callbacks for panStart, panEnd, panMove with the pan state, and the original event.
 **/
export const SWIPE_DISTANCE_THRESHOLD = 50;
export const SWIPE_VELOCITY_THRESHOLD = 0.12;
export const MINIMUM_SWIPE_DISTANCE = 5;
export default Mixin.create({
  //velocity is pixels per ms

  _panState: null,
  _animationPending: false,

  didInsertElement() {
    this._super(...arguments);
    this.addTouchListeners(this.element);
  },

  willDestroyElement() {
    this._super(...arguments);
    this.removeTouchListeners(this.element);
  },

  addTouchListeners(element) {
    if (this.site.mobileView) {
      this.touchStart = (e) => e.touches && this._panStart(e.touches[0]);
      this.touchMove = (e) => {
        const touchEvent = e.touches[0];
        touchEvent.type = "pointermove";
        this._panMove(touchEvent, e);
      };
      this.touchEnd = (e) => this._panMove({ type: "pointerup" }, e);
      this.touchCancel = (e) => this._panMove({ type: "pointercancel" }, e);

      const opts = {
        passive: false,
      };
      element.addEventListener("touchstart", this.touchStart, opts);
      element.addEventListener("touchmove", this.touchMove, opts);
      element.addEventListener("touchend", this.touchEnd, opts);
      element.addEventListener("touchcancel", this.touchCancel, opts);
    }
  },

  removeTouchListeners(element) {
    if (this.site.mobileView) {
      element.removeEventListener("touchstart", this.touchStart);
      element.removeEventListener("touchmove", this.touchMove);
      element.removeEventListener("touchend", this.touchEnd);
      element.removeEventListener("touchcancel", this.touchCancel);
    }
  },

  _calculateDirection(oldState, deltaX, deltaY) {
    if (oldState.start || !oldState.direction) {
      if (Math.abs(deltaX) > Math.abs(deltaY)) {
        return deltaX > 0 ? "right" : "left";
      } else {
        return deltaY > 0 ? "down" : "up";
      }
    }
    return oldState.direction;
  },

  _calculateNewPanState(oldState, e) {
    if (e.type === "pointerup" || e.type === "pointercancel") {
      return oldState;
    }
    const newTimestamp = Date.now();
    const timeDiffSeconds = newTimestamp - oldState.timestamp;
    if (timeDiffSeconds === 0) {
      return oldState;
    }
    //calculate delta x, y, distance from START location
    const deltaX = e.clientX - oldState.startLocation.x;
    const deltaY = e.clientY - oldState.startLocation.y;
    const distance = Math.sqrt(Math.pow(deltaX, 2) + Math.pow(deltaY, 2));

    //calculate velocity from previous event center location
    const eventDeltaX = e.clientX - oldState.center.x;
    const eventDeltaY = e.clientY - oldState.center.y;
    const velocityX = eventDeltaX / timeDiffSeconds;
    const velocityY = eventDeltaY / timeDiffSeconds;
    const deltaDistance = Math.sqrt(
      Math.pow(eventDeltaX, 2) + Math.pow(eventDeltaY, 2)
    );
    const velocity = deltaDistance / timeDiffSeconds;

    return {
      startLocation: oldState.startLocation,
      center: { x: e.clientX, y: e.clientY },
      velocity,
      velocityX,
      velocityY,
      deltaX,
      deltaY,
      distance,
      start: false,
      timestamp: newTimestamp,
      direction: this._calculateDirection(oldState, deltaX, deltaY),
    };
  },

  _panStart(e) {
    const newState = {
      center: { x: e.clientX, y: e.clientY },
      startLocation: { x: e.clientX, y: e.clientY },
      velocity: 0,
      velocityX: 0,
      velocityY: 0,
      deltaX: 0,
      deltaY: 0,
      distance: 0,
      start: true,
      timestamp: Date.now(),
      direction: null,
    };
    this.set("_panState", newState);
  },

  _panMove(e, originalEvent) {
    if (!this._panState) {
      this._panStart(e);
      return;
    }

    const previousState = this._panState;
    const newState = this._calculateNewPanState(previousState, e);
    if (previousState.start && newState.distance < MINIMUM_SWIPE_DISTANCE) {
      return;
    }
    this.set("_panState", newState);
    newState.originalEvent = originalEvent;
    if (previousState.start && "panStart" in this) {
      this.panStart(newState);
    } else if (
      (e.type === "pointerup" || e.type === "pointercancel") &&
      "panEnd" in this
    ) {
      this.panEnd(newState);
    } else if (e.type === "pointermove" && "panMove" in this) {
      if (this._animationPending) {
        return;
      }
      this._animationPending = true;
      window.requestAnimationFrame(() => {
        if (!this._animationPending) {
          return;
        }
        this.panMove(newState);
        this._animationPending = false;
      });
    }
  },
});
