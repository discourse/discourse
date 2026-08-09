const NEVER_CANCELLED = () => false;

export default class TravelLifecycle {
  #animations = new Set();
  #cancellationCallbacks = new Set();
  #frames = new Set();
  #cancelled = false;
  #isTravelCancelled;

  constructor(isTravelCancelled = NEVER_CANCELLED) {
    this.#isTravelCancelled = isTravelCancelled;
  }

  get cancelled() {
    return this.#cancelled || this.#isTravelCancelled();
  }

  cancel() {
    if (this.#cancelled) {
      return;
    }

    this.#cancelled = true;

    for (const frame of this.#frames) {
      cancelAnimationFrame(frame);
    }
    this.#frames.clear();

    for (const animation of [...this.#animations]) {
      animation.cancel?.();
    }
    this.#animations.clear();

    for (const callback of [...this.#cancellationCallbacks]) {
      callback();
    }
    this.#cancellationCallbacks.clear();
  }

  onCancel(callback) {
    if (this.cancelled) {
      callback();
      return () => {};
    }

    this.#cancellationCallbacks.add(callback);
    return () => this.#cancellationCallbacks.delete(callback);
  }

  requestFrame(callback) {
    if (this.cancelled) {
      return;
    }

    let frame = null;
    let ranSynchronously = false;
    frame = requestAnimationFrame((timestamp) => {
      ranSynchronously = true;
      if (frame !== null) {
        this.#frames.delete(frame);
      }
      if (!this.cancelled) {
        callback(timestamp);
      }
    });

    if (!ranSynchronously) {
      if (this.cancelled) {
        cancelAnimationFrame(frame);
      } else {
        this.#frames.add(frame);
      }
    }

    return frame;
  }

  waitForAnimation(animation, onFinish) {
    return new Promise((resolve) => {
      let settled = false;
      let stopTracking = () => {};
      let stopWatchingCancellation = () => {};

      const settle = (finished) => {
        if (settled) {
          return;
        }

        settled = true;
        if (finished) {
          onFinish?.();
        }
        animation.removeEventListener("finish", handleFinish);
        animation.removeEventListener("cancel", handleCancel);
        stopTracking();
        stopWatchingCancellation();
        resolve();
      };
      const handleFinish = () => settle(true);
      const handleCancel = () => settle(false);

      animation.addEventListener("finish", handleFinish);
      animation.addEventListener("cancel", handleCancel);
      stopTracking = this.#trackAnimation(animation);
      stopWatchingCancellation = this.onCancel(handleCancel);
    });
  }

  #trackAnimation(animation) {
    if (this.cancelled) {
      animation.cancel?.();
      return () => {};
    }

    this.#animations.add(animation);
    return () => this.#animations.delete(animation);
  }
}
