/**
   Pan events is a mixin that allows components to detect and respond to swipe gestures
   It fires callbacks for panStart, panEnd, panMove with the pan state, and the original event.
 **/
export const SWIPE_VELOCITY = 40;
export const SWIPE_DISTANCE_THRESHOLD = 50;
export const SWIPE_VELOCITY_THRESHOLD = 0.1;
export default Ember.Mixin.create({
  //velocity is pixels per ms

  _panState: null,

  didInsertElement() {
    this._super(...arguments);

    if (this.site.mobileView) {
      if ("onpointerdown" in document.documentElement) {
        this.$()
          .on("pointerdown", e => this._panStart(e))
          .on("pointermove", e => this._panMove(e, e))
          .on("pointerup", e => this._panMove(e, e))
          .on("pointercancel", e => this._panMove(e, e));
      } else if ("ontouchstart" in document.documentElement) {
        this.$()
          .on("touchstart", e => this._panStart(e.touches[0]))
          .on("touchmove", e => {
            const touchEvent = e.touches[0];
            touchEvent.type = "pointermove";
            this._panMove(touchEvent, e);
          })
          .on("touchend", e => this._panMove({ type: "pointerup" }, e))
          .on("touchcancel", e => this._panMove({ type: "pointercancel" }, e));
      }
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    if (this.site.mobileView) {
      this.$()
        .off("pointerdown")
        .off("pointerup")
        .off("pointermove")
        .off("pointercancel")
        .off("touchstart")
        .off("touchmove")
        .off("touchend")
        .off("touchcancel");
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
    const newTimestamp = new Date().getTime();
    const timeDiffSeconds = newTimestamp - oldState.timestamp;
    if (timeDiffSeconds === 0) {
      return oldState;
    }
    //calculate delta x, y, distance from START location
    const deltaX = e.clientX - oldState.startLocation.x;
    const deltaY = e.clientY - oldState.startLocation.y;
    const distance = Math.round(
      Math.sqrt(Math.pow(deltaX, 2) + Math.pow(deltaY, 2))
    );

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
      center: { x: Math.round(e.clientX), y: Math.round(e.clientY) },
      velocity,
      velocityX,
      velocityY,
      deltaX,
      deltaY,
      distance,
      start: false,
      timestamp: newTimestamp,
      direction: this._calculateDirection(oldState, deltaX, deltaY)
    };
  },

  _panStart(e) {
    const newState = {
      center: { x: Math.round(e.clientX), y: Math.round(e.clientY) },
      startLocation: { x: e.clientX, y: e.clientY },
      velocity: 0,
      velocityX: 0,
      velocityY: 0,
      deltaX: 0,
      deltaY: 0,
      distance: 0,
      start: true,
      timestamp: new Date().getTime(),
      direction: null
    };
    this.set("_panState", newState);
  },

  _panMove(e, originalEvent) {
    if (!this.get("_panState")) {
      this._panStart(e);
      return;
    }
    const previousState = this.get("_panState");
    const newState = this._calculateNewPanState(previousState, e);
    if (previousState.start && newState.distance < 5) {
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
      this.panMove(newState);
    }
  }
});
