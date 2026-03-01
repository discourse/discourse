import { EVENTS } from "../state-machine-events";

/**
 * Namespace for skip animation state machines.
 * Tracks whether opening/closing animations should be skipped.
 */
export default class SkipState {
  /**
   * State machine tracking whether opening animation should be skipped.
   * @type {import("../state-machine").default}
   */
  #openingMachine;

  /**
   * State machine tracking whether closing animation should be skipped.
   * @type {import("../state-machine").default}
   */
  #closingMachine;

  /**
   * @param {import("../state-machine").default} openingMachine - State machine for skip-opening state
   * @param {import("../state-machine").default} closingMachine - State machine for skip-closing state
   */
  constructor(openingMachine, closingMachine) {
    this.#openingMachine = openingMachine;
    this.#closingMachine = closingMachine;
  }

  /**
   * Whether the opening animation should be skipped.
   * @returns {boolean}
   */
  get isOpening() {
    return this.#openingMachine.matches("true");
  }

  /**
   * Whether the closing animation should be skipped.
   * @returns {boolean}
   */
  get isClosing() {
    return this.#closingMachine.matches("true");
  }

  /**
   * Enables skipping of the opening animation.
   * @returns {void}
   */
  enableOpening() {
    this.#openingMachine.send(EVENTS.TO_TRUE);
  }

  /**
   * Disables skipping of the opening animation.
   * @returns {void}
   */
  disableOpening() {
    this.#openingMachine.send(EVENTS.TO_FALSE);
  }

  /**
   * Enables skipping of the closing animation.
   * @returns {void}
   */
  enableClosing() {
    this.#closingMachine.send(EVENTS.TO_TRUE);
  }

  /**
   * Disables skipping of the closing animation.
   * @returns {void}
   */
  disableClosing() {
    this.#closingMachine.send(EVENTS.TO_FALSE);
  }
}
