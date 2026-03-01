import { EVENTS } from "../state-machine-events";

/**
 * Namespace for scroll container touch state machine.
 * Tracks whether touch is ongoing or ended.
 */
export default class TouchState {
  /**
   * The underlying state machine for scroll container touch.
   * @type {import("../state-machine").default}
   */
  #machine;

  /**
   * @param {import("../state-machine").default} machine - The scroll container touch state machine
   */
  constructor(machine) {
    this.#machine = machine;
  }

  /**
   * Whether a touch interaction is currently ongoing.
   * @returns {boolean}
   */
  get isOngoing() {
    return this.#machine.matches("ongoing");
  }

  /**
   * Whether the touch interaction has ended.
   * @returns {boolean}
   */
  get isEnded() {
    return this.#machine.matches("ended");
  }

  /**
   * Signal that a touch interaction has started.
   * @returns {void}
   */
  start() {
    this.#machine.send(EVENTS.TOUCH_START);
  }

  /**
   * Signal that a touch interaction has ended.
   * @returns {void}
   */
  end() {
    this.#machine.send(EVENTS.TOUCH_END);
  }
}
