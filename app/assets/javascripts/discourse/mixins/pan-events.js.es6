export default Ember.Mixin.create({
  //velocity is pixels per ms

  _panState: null,

  didInsertElement() {
    this._super();

    if (this.site.mobileView) {
      this.$()
        .on("pointerdown", e => this._panStart(e))
        .on("pointermove", e => this._panMove(e))
        .on("pointerup", e => this._panMove(e))
        .on("pointercancel", e => this._panMove(e));
    }
  },

  willDestroyElement() {
    this._super();

    if (this.site.mobileView) {
      this.$()
        .off("pointerdown")
        .off("pointerup")
        .off("pointermove")
        .off("pointercancel");
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

  _panMove(e) {
    if (!this.get("_panState")) {
      this._panStart(e);
      return;
    }
    const previousState = this.get("_panState");
    const newState = this._calculateNewPanState(previousState, e);
    this.set("_panState", newState);
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
