import ElementsState from "./state/elements";
import LongRunningState from "./state/long-running";
import OpennessState from "./state/openness";
import PositionState from "./state/position";
import SkipState from "./state/skip";
import StagingState from "./state/staging";
import StuckState from "./state/stuck";
import TouchState from "./state/touch";
import { EVENTS, MACHINE_NAMES } from "./state-machine-events";
import StateMachineGroup from "./state-machine-group";
import { GUARDS, POSITION_MACHINES, SHEET_MACHINES } from "./states";

/**
 * State machine facade for d-sheet.
 * Owns all state machines and provides namespaced access.
 */
export default class StateHelper {
  /**
   * Group managing all sheet-level state machines.
   * @type {StateMachineGroup}
   */
  #sheetMachines = new StateMachineGroup(SHEET_MACHINES, { guards: GUARDS });

  /**
   * Group managing position-related state machines.
   * @type {StateMachineGroup}
   */
  #positionMachines = new StateMachineGroup(POSITION_MACHINES, {
    guards: GUARDS,
  });

  /**
   * Initializes all state namespaces from their backing machines.
   */
  constructor() {
    /**
     * Openness lifecycle namespace (open, closed, opening, closing).
     * @type {OpennessState}
     */
    this.openness = new OpennessState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.OPENNESS)
    );

    /**
     * Animation staging namespace (none, opening, open, stepping, closing).
     * @type {StagingState}
     */
    this.staging = new StagingState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.STAGING),
      this.openness
    );

    /**
     * Stack position namespace (out, front, covered).
     * @type {PositionState}
     */
    this.position = new PositionState(
      this.#positionMachines.getMachine(MACHINE_NAMES.POSITION)
    );

    /**
     * Scroll container touch tracking namespace.
     * @type {TouchState}
     */
    this.touch = new TouchState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.SCROLL_CONTAINER_TOUCH)
    );

    /**
     * Detent boundary stuck state namespace (front and back).
     * @type {StuckState}
     */
    this.stuck = new StuckState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.FRONT_STUCK),
      this.#sheetMachines.getMachine(MACHINE_NAMES.BACK_STUCK)
    );

    /**
     * DOM elements readiness namespace.
     * @type {ElementsState}
     */
    this.elements = new ElementsState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.ELEMENTS_READY)
    );

    /**
     * Skip animation flags namespace (opening and closing).
     * @type {SkipState}
     */
    this.skip = new SkipState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_OPENING),
      this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_CLOSING)
    );

    /**
     * Long-running operation tracking namespace.
     * @type {LongRunningState}
     */
    this.longRunning = new LongRunningState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.LONG_RUNNING)
    );
  }

  /**
   * Begin enter animation - coordinates staging and position machines.
   * @param {boolean} [skipOpening=false] - Whether to skip the opening animation
   * @returns {void}
   */
  beginEnterAnimation(skipOpening = false) {
    this.staging.openPrepared();
    this.position.readyToGoFront(skipOpening);
  }

  /**
   * Begin exit animation - coordinates staging and position machines.
   * @param {boolean} [skipClosing=false] - Whether to skip the closing animation
   * @returns {void}
   */
  beginExitAnimation(skipClosing = false) {
    this.staging.actuallyClose(skipClosing);
    this.position.readyToGoOut();
  }

  /**
   * Begin immediate close - only staging, no position change.
   * @param {boolean} [skipClosing=true] - Whether to skip the closing animation
   * @returns {void}
   */
  beginImmediateClose(skipClosing = true) {
    this.staging.actuallyClose(skipClosing);
  }

  /**
   * Step the staging animation to the next phase.
   * @returns {void}
   */
  stepAnimation() {
    this.staging.actuallyStep();
  }

  /**
   * Subscribe to state machine changes.
   * @param {string} machineName - Machine name (openness, staging, position, etc.)
   * @param {Object} options - Subscription options
   * @param {string} options.timing - When to invoke ("immediate", "before-paint", "after-paint")
   * @param {string | string[]} options.state - State pattern(s) to match
   * @param {Function} options.callback - Function to call when state matches
   * @param {Function | boolean} [options.guard] - Optional guard condition
   * @param {string} [options.type] - "enter" (default) or "exit"
   * @returns {Function} Unsubscribe function
   */
  subscribe(machineName, options) {
    const machine = this.#getMachine(machineName);
    return machine.subscribe(options);
  }

  /**
   * Resolves a logical machine name to its underlying StateMachine instance.
   * @param {string} name - Logical machine name
   * @returns {import("./state-machine").default | undefined}
   */
  #getMachine(name) {
    const mapping = {
      openness: () => this.#sheetMachines.getMachine(MACHINE_NAMES.OPENNESS),
      staging: () => this.#sheetMachines.getMachine(MACHINE_NAMES.STAGING),
      position: () => this.#positionMachines.getMachine(MACHINE_NAMES.POSITION),
      touch: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.SCROLL_CONTAINER_TOUCH),
      longRunning: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.LONG_RUNNING),
      skipOpening: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_OPENING),
      skipClosing: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_CLOSING),
      backStuck: () => this.#sheetMachines.getMachine(MACHINE_NAMES.BACK_STUCK),
      frontStuck: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.FRONT_STUCK),
      elementsReady: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.ELEMENTS_READY),
    };
    return mapping[name]?.();
  }

  /**
   * Cleanup all state machines by removing their subscriptions.
   * @returns {void}
   */
  cleanup() {
    for (const machine of [
      this.#sheetMachines.getMachine(MACHINE_NAMES.OPENNESS),
      this.#sheetMachines.getMachine(MACHINE_NAMES.STAGING),
      this.#positionMachines.getMachine(MACHINE_NAMES.POSITION),
      this.#sheetMachines.getMachine(MACHINE_NAMES.SCROLL_CONTAINER_TOUCH),
      this.#sheetMachines.getMachine(MACHINE_NAMES.LONG_RUNNING),
      this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_OPENING),
      this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_CLOSING),
      this.#sheetMachines.getMachine(MACHINE_NAMES.BACK_STUCK),
      this.#sheetMachines.getMachine(MACHINE_NAMES.FRONT_STUCK),
      this.#sheetMachines.getMachine(MACHINE_NAMES.ELEMENTS_READY),
    ]) {
      machine.cleanup();
    }
  }

  /**
   * Send a message to the position machine.
   * Used by stacking adapter for inter-sheet communication.
   * @param {string | {type: string}} message - Message type or object to send
   * @param {Object} [context={}] - Context data for guards
   * @returns {boolean} Whether any transition occurred
   */
  sendToPosition(message, context = {}) {
    return this.#positionMachines
      .getMachine(MACHINE_NAMES.POSITION)
      .send(message, context);
  }

  /**
   * Advance position to next state (auto-transition).
   * @returns {void}
   */
  advancePositionAuto() {
    this.#positionMachines.getMachine(MACHINE_NAMES.POSITION).send("");
  }

  /**
   * Flush closed status to preparing-opening (auto-transition).
   * @returns {void}
   */
  flushClosedStatus() {
    this.#sheetMachines.getMachine(MACHINE_NAMES.OPENNESS).send({
      machine: "openness:closed.status",
      type: "",
    });
  }

  /**
   * Open all sheet machines (broadcasts OPEN to all).
   * @returns {void}
   */
  broadcastOpen() {
    this.#sheetMachines.send({ type: EVENTS.OPEN });
  }
}
