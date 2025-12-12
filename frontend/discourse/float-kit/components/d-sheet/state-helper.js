/**
 * State machine helper for d-sheet.
 * Provides named methods for state transitions instead of raw message sends.
 *
 * @class StateHelper
 */
export default class StateHelper {
  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.c = controller;
  }

  /**
   * Get the main state machine.
   *
   * @returns {Object}
   */
  get stateMachine() {
    return this.c.stateMachine;
  }

  /**
   * Get the staging state machine.
   *
   * @returns {Object}
   */
  get stagingMachine() {
    return this.c.stagingMachine;
  }

  /**
   * Get the position state machine.
   *
   * @returns {Object}
   */
  get positionMachine() {
    return this.c.positionMachine;
  }

  // ─── Opening Flow ───────────────────────────────────────────────────

  /**
   * Initiate sheet opening.
   */
  initiateOpen() {
    this.stateMachine.send("OPEN");
  }

  /**
   * Mark sheet as prepared (dimensions calculated).
   */
  markPrepared() {
    this.stateMachine.send("PREPARED");
  }

  /**
   * Begin the enter animation sequence.
   *
   * @param {boolean} skipOpening - Whether to skip the opening animation
   */
  beginEnterAnimation(skipOpening = false) {
    this.stagingMachine.send("OPEN_PREPARED", {
      opennessState: this.stateMachine.current,
    });
    this.positionMachine.send("READY_TO_GO_FRONT", { skipOpening });
  }

  /**
   * Complete the enter/exit animation.
   */
  completeAnimation() {
    this.stateMachine.send("ANIMATION_COMPLETE");
  }

  /**
   * Advance staging machine to next state.
   */
  advanceStaging() {
    this.stagingMachine.send("NEXT");
  }

  // ─── Closing Flow ───────────────────────────────────────────────────

  /**
   * Initiate sheet closing.
   */
  initiateClose() {
    this.stateMachine.send("CLOSE");
  }

  /**
   * Begin the exit animation sequence.
   *
   * @param {boolean} skipClosing - Whether to skip closing animation
   */
  beginExitAnimation(skipClosing = false) {
    this.stagingMachine.send("ACTUALLY_CLOSE", {
      opennessState: this.stateMachine.current,
      skipClosing,
    });
    this.positionMachine.send("READY_TO_GO_OUT");
  }

  /**
   * Go directly to out position (for immediate close).
   */
  goOut() {
    this.positionMachine.send("GO_OUT");
  }

  /**
   * Complete the pending flush after close.
   */
  flushComplete() {
    this.stateMachine.send("FLUSH_COMPLETE");
  }

  // ─── Scroll/Swipe Flow ──────────────────────────────────────────────

  /**
   * Signal scroll has started.
   */
  scrollStart() {
    if (!this.stateMachine.matches("open.scroll.ongoing")) {
      this.stateMachine.send("SCROLL_START");
    }
  }

  /**
   * Signal scroll has ended.
   */
  scrollEnd() {
    if (this.stateMachine.matches("open.scroll.ongoing")) {
      this.stateMachine.send("SCROLL_END");
    }
  }

  /**
   * Signal swipe gesture has started.
   */
  swipeStart() {
    this.stateMachine.send("SWIPE_START");
    if (this.stateMachine.matches("open.scroll.ongoing")) {
      this.stateMachine.send("SCROLL_END");
    }
  }

  /**
   * Signal swipe gesture has ended.
   */
  swipeEnd() {
    this.stateMachine.send("SWIPE_END");
  }

  /**
   * Trigger swipe-out close.
   */
  swipeOut() {
    this.stateMachine.send("SWIPE_OUT");
  }

  // ─── Step Flow ──────────────────────────────────────────────────────

  /**
   * Begin stepping to next detent.
   *
   * @param {number} detent - Target detent index
   */
  beginStep(detent) {
    this.stateMachine.send({ type: "STEP", detent });
  }

  /**
   * Begin actual stepping animation.
   */
  actuallyStep() {
    this.stagingMachine.send("ACTUALLY_STEP", {
      opennessState: this.stateMachine.current,
    });
  }

  /**
   * Signal move has started (for stuck position stepping).
   */
  moveStart() {
    this.stateMachine.send("MOVE_START");
  }

  /**
   * Signal move has ended.
   */
  moveEnd() {
    this.stateMachine.send("MOVE_END");
  }

  // ─── Position Machine ───────────────────────────────────────────────

  /**
   * Advance position machine to next state.
   */
  advancePosition() {
    this.positionMachine.send("NEXT");
  }

  /**
   * Go to front idle state.
   */
  gotoFrontIdle() {
    this.positionMachine.send("GOTO_FRONT_IDLE");
  }

  /**
   * Go to covered idle state.
   */
  gotoCoveredIdle() {
    this.positionMachine.send("GOTO_COVERED_IDLE");
  }

  // ─── Staging Machine ────────────────────────────────────────────────

  /**
   * Signal staging to go down (for stacking).
   */
  goDown() {
    this.stagingMachine.send("GO_DOWN", {
      opennessState: this.stateMachine.current,
    });
  }

  /**
   * Signal staging to go up (for stacking).
   */
  goUp() {
    this.stagingMachine.send("GO_UP", {
      opennessState: this.stateMachine.current,
    });
  }

  /**
   * Begin closing without position machine notification.
   *
   * @param {boolean} skipClosing - Whether to skip closing animation
   */
  beginClosingImmediate(skipClosing = true) {
    this.stagingMachine.send("ACTUALLY_CLOSE", {
      opennessState: this.stateMachine.current,
      skipClosing,
    });
  }

  /**
   * Send a message to the main state machine.
   *
   * @param {string|Object} message
   */
  send(message) {
    this.stateMachine.send(message);
  }

  /**
   * Send a message to the position machine.
   *
   * @param {string|Object} message
   * @param {Object} context
   * @returns {boolean}
   */
  sendToPosition(message, context = {}) {
    return this.positionMachine.send(message, context);
  }

  // ─── Queries ────────────────────────────────────────────────────────

  /**
   * Get current main state.
   *
   * @returns {string}
   */
  get currentState() {
    return this.stateMachine.current;
  }

  /**
   * Get current staging state.
   *
   * @returns {string}
   */
  get staging() {
    return this.stagingMachine.current;
  }

  /**
   * Get current position state.
   *
   * @returns {string}
   */
  get position() {
    return this.positionMachine.current;
  }

  /**
   * Check if sheet is open.
   *
   * @returns {boolean}
   */
  get isOpen() {
    return this.stateMachine.current === "open";
  }

  /**
   * Check if sheet is closing.
   *
   * @returns {boolean}
   */
  get isClosing() {
    return this.stateMachine.current === "closing";
  }

  /**
   * Check if sheet is opening.
   *
   * @returns {boolean}
   */
  get isOpening() {
    return (
      this.stateMachine.current === "opening" ||
      this.stateMachine.current === "preparing-opening"
    );
  }

  /**
   * Check if staging is active.
   *
   * @returns {boolean}
   */
  get isStagingActive() {
    return this.staging !== "none";
  }

  /**
   * Check if scroll is ongoing.
   *
   * @returns {boolean}
   */
  matchesScrollOngoing() {
    return this.stateMachine.matches("open.scroll.ongoing");
  }

  /**
   * Check if scroll has ended.
   *
   * @returns {boolean}
   */
  matchesScrollEnded() {
    return this.stateMachine.matches("open.scroll.ended");
  }

  /**
   * Check if swipe is ongoing.
   *
   * @returns {boolean}
   */
  matchesSwipeOngoing() {
    return this.stateMachine.matches("open.swipe.ongoing");
  }

  /**
   * Check if in closed.pending state.
   *
   * @returns {boolean}
   */
  matchesClosedPending() {
    return this.stateMachine.matches("closed.pending");
  }

  /**
   * Check if position machine is in front-opening state.
   *
   * @returns {boolean}
   */
  isPositionFrontOpening() {
    return this.positionMachine.current === "front-opening";
  }

  /**
   * Check if position machine is in front-closing state.
   *
   * @returns {boolean}
   */
  isPositionFrontClosing() {
    return this.positionMachine.current === "front-closing";
  }

  /**
   * Check if staging is in specific state.
   *
   * @param {string} state - State to check
   * @returns {boolean}
   */
  isStagingIn(state) {
    return this.stagingMachine.matches(state);
  }
}
