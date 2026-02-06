/**
 * Namespace for stuck state machines (front and back).
 * Tracks whether sheet is stuck at detent boundaries.
 */
export default class StuckState {
  /**
   * State machine tracking front detent stuck status.
   * @type {import("../state-machine").default}
   */
  #frontMachine;

  /**
   * State machine tracking back detent stuck status.
   * @type {import("../state-machine").default}
   */
  #backMachine;

  /**
   * @param {import("../state-machine").default} frontMachine - State machine for front stuck state
   * @param {import("../state-machine").default} backMachine - State machine for back stuck state
   */
  constructor(frontMachine, backMachine) {
    this.#frontMachine = frontMachine;
    this.#backMachine = backMachine;
  }

  /**
   * Whether the sheet is stuck at the front detent.
   * @returns {boolean}
   */
  get isFront() {
    return this.#frontMachine.matches("true");
  }

  /**
   * Whether the sheet is stuck at the back detent.
   * @returns {boolean}
   */
  get isBack() {
    return this.#backMachine.matches("true");
  }

  /**
   * Whether the sheet is stuck at either detent.
   * @returns {boolean}
   */
  get isEither() {
    return this.isFront || this.isBack;
  }

  /**
   * Transition the front machine to the stuck state.
   * @returns {void}
   */
  startFront() {
    this.#frontMachine.send("STUCK_START");
  }

  /**
   * Transition the front machine out of the stuck state.
   * @returns {void}
   */
  endFront() {
    this.#frontMachine.send("STUCK_END");
  }

  /**
   * Transition the back machine to the stuck state.
   * @returns {void}
   */
  startBack() {
    this.#backMachine.send("STUCK_START");
  }

  /**
   * Transition the back machine out of the stuck state.
   * @returns {void}
   */
  endBack() {
    this.#backMachine.send("STUCK_END");
  }

  /**
   * End stuck state on all machines that are currently stuck.
   * @returns {void}
   */
  endAll() {
    if (this.isFront) {
      this.endFront();
    }
    if (this.isBack) {
      this.endBack();
    }
  }
}
