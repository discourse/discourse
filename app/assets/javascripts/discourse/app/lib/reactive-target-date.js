import { cached } from "@glimmer/tracking";
import { destroy, isDestroyed, registerDestructor } from "@ember/destroyable";
import { dedupeTracked } from "./tracked-tools";

const MAX_CHECK_INTERVAL_MS = 60_000;
const DELAY_CHECK_MS = 50;

export default class ReactiveTargetDate {
  #timer;

  @dedupeTracked _targetHasPassed;

  constructor(targetDateCallback) {
    registerDestructor(this, () => clearTimeout(this.#timer));
    this.targetDateCallback = targetDateCallback;
  }

  @cached
  get hasPassed() {
    this.#check();
    return this._targetHasPassed;
  }

  #check() {
    if (isDestroyed(this)) {
      throw "Cannot use a destroyed ReactiveTargetDate";
    }

    clearTimeout(this.#timer);

    const now = new Date();
    const rawTarget = this.targetDateCallback();

    if (rawTarget === undefined || rawTarget === null) {
      this._targetHasPassed = null;
      return;
    }

    const target = new Date(rawTarget);

    if (target < now) {
      this._targetHasPassed = true;
    } else {
      this._targetHasPassed = false;
      const msToTarget = target - now;
      const checkAgainMs = Math.min(
        msToTarget + DELAY_CHECK_MS,
        MAX_CHECK_INTERVAL_MS
      );
      this.#timer = setTimeout(() => this.#check(), checkAgainMs);
    }
  }

  destroy() {
    destroy(this);
  }
}
