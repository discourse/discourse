/**
 * Namespace for elements ready state machine.
 * Tracks whether DOM elements have been registered.
 */
export default class ElementsState {
  /**
   * State machine tracking element registration status.
   * @type {import("../state-machine").default}
   */
  #machine;

  /**
   * Creates an ElementsState wrapping the given state machine.
   * @param {import("../state-machine").default} machine - The elementsReady state machine instance
   */
  constructor(machine) {
    this.#machine = machine;
  }

  /**
   * Whether all required DOM elements have been registered.
   * @type {boolean}
   */
  get isReady() {
    return this.#machine.matches("true");
  }

  /**
   * Whether required DOM elements have not yet been registered.
   * @type {boolean}
   */
  get isNotReady() {
    return this.#machine.matches("false");
  }

  /**
   * Marks DOM elements as registered by sending the ELEMENTS_REGISTERED event.
   * @returns {void}
   */
  markRegistered() {
    this.#machine.send("ELEMENTS_REGISTERED");
  }

  /**
   * Resets the element registration state back to its initial value.
   * @returns {void}
   */
  reset() {
    this.#machine.send("RESET");
  }
}
