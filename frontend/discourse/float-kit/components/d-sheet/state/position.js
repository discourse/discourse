/**
 * Namespace for position state machine.
 * Tracks sheet position in stack: out, front, covered.
 */
export default class PositionState {
  /**
   * The underlying state machine driving position transitions.
   *
   * @type {import("../state-machine").default}
   */
  #machine;

  /**
   * @param {import("../state-machine").default} machine - The state machine instance to wrap
   */
  constructor(machine) {
    this.#machine = machine;
  }

  /**
   * Whether the sheet is in the "out" position (not visible in the stack).
   *
   * @returns {boolean}
   */
  get isOut() {
    return this.#machine.matches("out");
  }

  /**
   * Whether the sheet is in the "front" position (topmost in the stack).
   *
   * @returns {boolean}
   */
  get isFront() {
    return this.#machine.matches("front");
  }

  /**
   * Whether the sheet is in the "covered" position (behind another sheet).
   *
   * @returns {boolean}
   */
  get isCovered() {
    return this.#machine.matches("covered");
  }

  /**
   * Whether the sheet is front and in the opening transition.
   *
   * @returns {boolean}
   */
  get isFrontOpening() {
    return this.#machine.matches("front.status:opening");
  }

  /**
   * Whether the sheet is front and in the closing transition.
   *
   * @returns {boolean}
   */
  get isFrontClosing() {
    return this.#machine.matches("front.status:closing");
  }

  /**
   * Whether the sheet is front and idle (fully open, no transition in progress).
   *
   * @returns {boolean}
   */
  get isFrontIdle() {
    return this.#machine.matches("front.status:idle");
  }

  /**
   * Whether the sheet is covered and idle.
   *
   * @returns {boolean}
   */
  get isCoveredIdle() {
    return this.#machine.matches("covered.status:idle");
  }

  /**
   * Whether the sheet is in any idle state (out, front idle, or covered idle).
   *
   * @returns {boolean}
   */
  get isIdle() {
    return (
      this.isOut ||
      this.#machine.matches("front.status:idle") ||
      this.#machine.matches("covered.status:idle")
    );
  }

  /**
   * Transitions the sheet to the "out" position.
   *
   * @returns {void}
   */
  goOut() {
    this.#machine.send("GO_OUT");
  }

  /**
   * Advances the position state machine to the next state.
   *
   * @returns {void}
   */
  advance() {
    this.#machine.send("NEXT");
  }

  /**
   * Transitions directly to the front idle state.
   *
   * @returns {void}
   */
  goToFrontIdle() {
    this.#machine.send("GOTO_front");
  }

  /**
   * Transitions directly to the covered idle state.
   *
   * @returns {void}
   */
  goToCoveredIdle() {
    this.#machine.send("GOTO_idle");
  }

  /**
   * Signals readiness to transition to the front position.
   *
   * @param {boolean} skipOpening - Whether to skip the opening animation
   * @returns {void}
   */
  readyToGoFront(skipOpening) {
    this.#machine.send("READY_TO_GO_FRONT", { skipOpening });
  }

  /**
   * Signals readiness to transition to the out position.
   *
   * @returns {void}
   */
  readyToGoOut() {
    this.#machine.send("READY_TO_GO_OUT");
  }

  /**
   * The current state path of the underlying machine.
   *
   * @returns {string}
   */
  get current() {
    return this.#machine.current;
  }

  /**
   * Checks if the position machine matches the given state pattern.
   *
   * @param {string} state - State pattern to match (e.g., "front", "front.status:idle")
   * @returns {boolean}
   */
  matches(state) {
    return this.#machine.matches(state);
  }
}
