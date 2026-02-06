import ElementsState from "./state/elements";
import LongRunningState from "./state/long-running";
import OpennessState from "./state/openness";
import PositionState from "./state/position";
import SkipState from "./state/skip";
import StagingState from "./state/staging";
import StuckState from "./state/stuck";
import TouchState from "./state/touch";
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
      this.#sheetMachines.getMachine("openness")
    );

    /**
     * Animation staging namespace (none, opening, open, stepping, closing).
     * @type {StagingState}
     */
    this.staging = new StagingState(
      this.#sheetMachines.getMachine("staging"),
      this.openness
    );

    /**
     * Stack position namespace (out, front, covered).
     * @type {PositionState}
     */
    this.position = new PositionState(
      this.#positionMachines.getMachine("position")
    );

    /**
     * Scroll container touch tracking namespace.
     * @type {TouchState}
     */
    this.touch = new TouchState(
      this.#sheetMachines.getMachine("scrollContainerTouch")
    );

    /**
     * Detent boundary stuck state namespace (front and back).
     * @type {StuckState}
     */
    this.stuck = new StuckState(
      this.#sheetMachines.getMachine("frontStuck"),
      this.#sheetMachines.getMachine("backStuck")
    );

    /**
     * DOM elements readiness namespace.
     * @type {ElementsState}
     */
    this.elements = new ElementsState(
      this.#sheetMachines.getMachine("elementsReady")
    );

    /**
     * Skip animation flags namespace (opening and closing).
     * @type {SkipState}
     */
    this.skip = new SkipState(
      this.#sheetMachines.getMachine("skipOpening"),
      this.#sheetMachines.getMachine("skipClosing")
    );

    /**
     * Long-running operation tracking namespace.
     * @type {LongRunningState}
     */
    this.longRunning = new LongRunningState(
      this.#sheetMachines.getMachine("longRunning")
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
      openness: () => this.#sheetMachines.getMachine("openness"),
      staging: () => this.#sheetMachines.getMachine("staging"),
      position: () => this.#positionMachines.getMachine("position"),
      touch: () => this.#sheetMachines.getMachine("scrollContainerTouch"),
      longRunning: () => this.#sheetMachines.getMachine("longRunning"),
      skipOpening: () => this.#sheetMachines.getMachine("skipOpening"),
      skipClosing: () => this.#sheetMachines.getMachine("skipClosing"),
      backStuck: () => this.#sheetMachines.getMachine("backStuck"),
      frontStuck: () => this.#sheetMachines.getMachine("frontStuck"),
      elementsReady: () => this.#sheetMachines.getMachine("elementsReady"),
    };
    return mapping[name]?.();
  }

  /**
   * Cleanup all state machines by removing their subscriptions.
   * @returns {void}
   */
  cleanup() {
    this.#sheetMachines.getMachine("openness").cleanup();
    this.#sheetMachines.getMachine("staging").cleanup();
    this.#positionMachines.getMachine("position").cleanup();
    this.#sheetMachines.getMachine("scrollContainerTouch").cleanup();
    this.#sheetMachines.getMachine("longRunning").cleanup();
    this.#sheetMachines.getMachine("skipOpening").cleanup();
    this.#sheetMachines.getMachine("skipClosing").cleanup();
    this.#sheetMachines.getMachine("backStuck").cleanup();
    this.#sheetMachines.getMachine("frontStuck").cleanup();
    this.#sheetMachines.getMachine("elementsReady").cleanup();
  }

  /**
   * Send a message to the position machine.
   * Used by stacking adapter for inter-sheet communication.
   * @param {string | {type: string}} message - Message type or object to send
   * @param {Object} [context={}] - Context data for guards
   * @returns {boolean} Whether any transition occurred
   */
  sendToPosition(message, context = {}) {
    return this.#positionMachines.getMachine("position").send(message, context);
  }

  /**
   * Advance position to next state (auto-transition).
   * @returns {void}
   */
  advancePositionAuto() {
    this.#positionMachines.getMachine("position").send("");
  }

  /**
   * Flush closed status to preparing-opening (auto-transition).
   * @returns {void}
   */
  flushClosedStatus() {
    this.#sheetMachines.getMachine("openness").send({
      machine: "openness:closed.status",
      type: "",
    });
  }

  /**
   * Open all sheet machines (broadcasts OPEN to all).
   * @returns {void}
   */
  broadcastOpen() {
    this.#sheetMachines.send({ type: "OPEN" });
  }
}
