/**
 * Namespace for long-running operation state machine.
 * Tracks whether a long-running operation is in progress.
 */
export default class LongRunningState {
  /**
   * The backing boolean state machine.
   * @type {import("../state-machine").default}
   */
  #machine;

  /**
   * @param {import("../state-machine").default} machine - Boolean state machine for long-running tracking
   */
  constructor(machine) {
    this.#machine = machine;
  }

  /**
   * Whether a long-running operation is currently active.
   * @returns {boolean}
   */
  get isActive() {
    return this.#machine.matches("true");
  }

  /**
   * Whether no long-running operation is in progress.
   * @returns {boolean}
   */
  get isInactive() {
    return this.#machine.matches("false");
  }

  /**
   * Signals the start of a long-running operation.
   * @returns {void}
   */
  start() {
    this.#machine.send("TO_TRUE");
  }

  /**
   * Signals the end of a long-running operation.
   * @returns {void}
   */
  end() {
    this.#machine.send("TO_FALSE");
  }
}
