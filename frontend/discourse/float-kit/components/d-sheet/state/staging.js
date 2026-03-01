import { EVENTS } from "../state-machine-events";

/**
 * Namespace for staging/animation state machine.
 * Tracks animation phases: none, opening, open, stepping, closing, going-down, going-up.
 */
export default class StagingState {
  /** @type {import("../state-machine").default} */
  #machine;

  /** @type {import("./openness").default} */
  #openness;

  /**
   * @param {import("../state-machine").default} machine - The staging state machine instance
   * @param {import("./openness").default} opennessNamespace - The openness state namespace for context
   */
  constructor(machine, opennessNamespace) {
    this.#machine = machine;
    this.#openness = opennessNamespace;
  }

  /**
   * Whether the staging machine is in the "none" (idle) state.
   *
   * @type {boolean}
   */
  get isNone() {
    return this.#machine.current === "none";
  }

  /**
   * Whether the staging machine is in the "opening" animation phase.
   *
   * @type {boolean}
   */
  get isOpening() {
    return this.#machine.current === "opening";
  }

  /**
   * Whether the staging machine is in the "open" state.
   *
   * @type {boolean}
   */
  get isOpen() {
    return this.#machine.current === "open";
  }

  /**
   * Whether the staging machine is in the "stepping" animation phase.
   *
   * @type {boolean}
   */
  get isStepping() {
    return this.#machine.current === "stepping";
  }

  /**
   * Whether the staging machine is in the "closing" animation phase.
   *
   * @type {boolean}
   */
  get isClosing() {
    return this.#machine.current === "closing";
  }

  /**
   * Whether the staging machine is in the "going-down" animation phase.
   *
   * @type {boolean}
   */
  get isGoingDown() {
    return this.#machine.current === "going-down";
  }

  /**
   * Whether the staging machine is in the "going-up" animation phase.
   *
   * @type {boolean}
   */
  get isGoingUp() {
    return this.#machine.current === "going-up";
  }

  /**
   * Whether any animation is in progress (not in "none" state).
   *
   * @type {boolean}
   */
  get isAnimating() {
    return this.#machine.current !== "none";
  }

  /**
   * Check if the staging machine matches a given state pattern.
   *
   * @param {string} state - State pattern to match against
   * @returns {boolean} Whether the machine matches the state
   */
  matches(state) {
    return this.#machine.matches(state);
  }

  /**
   * Signal that opening preparation is complete, transitioning to the opening phase.
   */
  openPrepared() {
    this.#machine.send(EVENTS.OPEN_PREPARED, {
      opennessState: this.#openness.current,
    });
  }

  /**
   * Trigger the close animation, optionally skipping the closing phase.
   *
   * @param {boolean} [skipClosing=false] - Whether to skip the closing animation
   */
  actuallyClose(skipClosing = false) {
    this.#machine.send(EVENTS.ACTUALLY_CLOSE, {
      opennessState: this.#openness.current,
      skipClosing,
    });
  }

  /**
   * Trigger the step animation between detents.
   */
  actuallyStep() {
    this.#machine.send(EVENTS.ACTUALLY_STEP, {
      opennessState: this.#openness.current,
    });
  }

  /**
   * Advance the staging machine to its next state via the NEXT message.
   */
  advance() {
    this.#machine.send(EVENTS.NEXT);
  }

  /**
   * Trigger the going-down animation phase.
   */
  goDown() {
    this.#machine.send(EVENTS.GO_DOWN, {
      opennessState: this.#openness.current,
    });
  }

  /**
   * Trigger the going-up animation phase.
   */
  goUp() {
    this.#machine.send(EVENTS.GO_UP, {
      opennessState: this.#openness.current,
    });
  }

  /**
   * The current state of the staging machine.
   *
   * @type {string}
   */
  get current() {
    return this.#machine.current;
  }
}
