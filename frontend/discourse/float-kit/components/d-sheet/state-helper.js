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
   * Get the animation state machine.
   *
   * @returns {Object}
   */
  get animationStateMachine() {
    return this.c.animationStateMachine;
  }

  /**
   * Get the position state machine.
   *
   * @returns {Object}
   */
  get positionMachine() {
    return this.c.positionMachine;
  }

  /**
   * Get the touch state machine.
   *
   * @returns {Object}
   */
  get touchMachine() {
    return this.c.touchMachine;
  }

  /**
   * Get the sheet machines group.
   *
   * @returns {StateMachineGroup}
   */
  get sheetMachines() {
    return this.c.sheetMachines;
  }

  /**
   * Get the position machines group.
   *
   * @returns {StateMachineGroup}
   */
  get positionMachines() {
    return this.c.positionMachines;
  }

  /**
   * Get the long-running state machine.
   *
   * @returns {Object}
   */
  get longRunningMachine() {
    return this.c.longRunningMachine;
  }

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
    this.animationStateMachine.send("OPEN_PREPARED", {
      opennessState: this.stateMachine.current,
    });
    this.positionMachine.send("READY_TO_GO_FRONT", { skipOpening });
  }

  /**
   * Complete the enter/exit animation.
   * Sends NEXT for both opening and closing.
   */
  completeAnimation() {
    this.stateMachine.send("NEXT");
  }

  /**
   * Advance animation state machine to next state.
   */
  advanceAnimation() {
    this.animationStateMachine.send("NEXT");
  }

  /**
   * Initiate sheet closing.
   */
  initiateClose() {
    this.stateMachine.send("READY_TO_CLOSE");
  }

  /**
   * Begin the exit animation sequence.
   *
   * @param {boolean} skipClosing - Whether to skip closing animation
   */
  beginExitAnimation(skipClosing = false) {
    this.animationStateMachine.send("ACTUALLY_CLOSE", {
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
    if (!this.stateMachine.matches("open.scroll:ongoing")) {
      this.stateMachine.send("SCROLL_START");
    }
  }

  /**
   * Signal scroll has ended.
   */
  scrollEnd() {
    if (this.stateMachine.matches("open.scroll:ongoing")) {
      this.stateMachine.send("SCROLL_END");
    }
  }

  /**
   * Signal swipe gesture has started.
   */
  swipeStart() {
    this.stateMachine.send("SWIPE_START");
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
    this.stateMachine.send("SWIPED_OUT");
  }

  /**
   * Begin stepping to next detent.
   *
   * @param {number} detent - Target detent index
   */
  beginStep(detent) {
    this.stateMachine.send({ type: "STEP", detent });
  }

  /**
   * Begin stepping animation.
   */
  stepAnimation() {
    this.animationStateMachine.send("ACTUALLY_STEP", {
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

  // ─── Touch Flow ────────────────────────────────────────────────────

  /**
   * Signal touch has started.
   */
  touchStart() {
    this.touchMachine.send("TOUCH_START");
  }

  /**
   * Signal touch has ended.
   */
  touchEnd() {
    this.touchMachine.send("TOUCH_END");
  }

  /**
   * Advance position machine to next state.
   */
  advancePosition() {
    this.positionMachine.send("NEXT");
  }

  /**
   * Go to front idle state.
   */
  goToFrontIdle() {
    this.positionMachine.send("GOTO_front");
  }

  /**
   * Go to covered idle state.
   */
  goToCoveredIdle() {
    this.positionMachine.send("GOTO_idle");
  }

  /**
   * Signal animation state to go down (for stacking).
   */
  goDown() {
    this.animationStateMachine.send("GO_DOWN", {
      opennessState: this.stateMachine.current,
    });
  }

  /**
   * Signal animation state to go up (for stacking).
   */
  goUp() {
    this.animationStateMachine.send("GO_UP", {
      opennessState: this.stateMachine.current,
    });
  }

  /**
   * Begin closing without position machine notification.
   *
   * @param {boolean} skipClosing - Whether to skip closing animation
   */
  beginImmediateClose(skipClosing = true) {
    this.animationStateMachine.send("ACTUALLY_CLOSE", {
      opennessState: this.stateMachine.current,
      skipClosing,
    });
  }

  /**
   * Get current main state.
   *
   * @returns {string}
   */
  get currentState() {
    return this.stateMachine.current;
  }

  /**
   * Get current animation state.
   *
   * @returns {string}
   */
  get animationState() {
    return this.animationStateMachine.current;
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
      this.stateMachine.matches("closed.status:preparing-opening") ||
      this.stateMachine.matches("closed.status:preparing-open")
    );
  }

  /**
   * Check if an animation is active.
   *
   * @returns {boolean}
   */
  get isAnimating() {
    return this.animationState !== "none";
  }

  /**
   * Check if scroll is ongoing.
   *
   * @returns {boolean}
   */
  isScrollOngoing() {
    return this.stateMachine.matches("open.scroll:ongoing");
  }

  /**
   * Check if scroll has ended.
   *
   * @returns {boolean}
   */
  isScrollEnded() {
    return this.stateMachine.matches("open.scroll:ended");
  }

  /**
   * Check if swipe is ongoing.
   *
   * @returns {boolean}
   */
  isSwipeOngoing() {
    return this.stateMachine.matches("open.swipe:ongoing");
  }

  /**
   * Check if move is ongoing.
   *
   * @returns {boolean}
   */
  isMoveOngoing() {
    return this.stateMachine.matches("open.move:ongoing");
  }

  /**
   * Check if in closed.pending state.
   *
   * @returns {boolean}
   */
  isClosedPending() {
    return this.stateMachine.matches("closed.status:pending");
  }

  /**
   * Check if in closed.safe-to-unmount state.
   *
   * @returns {boolean}
   */
  isClosedSafeToUnmount() {
    return this.stateMachine.matches("closed.status:safe-to-unmount");
  }

  /**
   * Check if position machine is in front.status:opening state.
   *
   * @returns {boolean}
   */
  isPositionFrontOpening() {
    return this.positionMachine.matches("front.status:opening");
  }

  /**
   * Check if position machine is in front.status:closing state.
   *
   * @returns {boolean}
   */
  isPositionFrontClosing() {
    return this.positionMachine.matches("front.status:closing");
  }

  /**
   * Check if position is in the "front" parent state.
   *
   * @returns {boolean}
   */
  isPositionFront() {
    return this.positionMachine.matches("front");
  }

  /**
   * Check if position is in the "covered" parent state.
   *
   * @returns {boolean}
   */
  isPositionCovered() {
    return this.positionMachine.matches("covered");
  }

  /**
   * Check if position is in covered.status:going-down state.
   *
   * @returns {boolean}
   */
  isPositionCoveredGoingDown() {
    return this.positionMachine.matches("covered.status:going-down");
  }

  /**
   * Check if position is in covered.status:idle state.
   *
   * @returns {boolean}
   */
  isPositionCoveredIdle() {
    return this.positionMachine.matches("covered.status:idle");
  }

  /**
   * Check if position is in covered.status:going-up state.
   *
   * @returns {boolean}
   */
  isPositionCoveredGoingUp() {
    return this.positionMachine.matches("covered.status:going-up");
  }

  /**
   * Check if position is in covered.status:indeterminate state.
   *
   * @returns {boolean}
   */
  isPositionCoveredIndeterminate() {
    return this.positionMachine.matches("covered.status:indeterminate");
  }

  /**
   * Check if in a specific animation state.
   *
   * @param {string} state - State to check
   * @returns {boolean}
   */
  isInAnimationState(state) {
    return this.animationStateMachine.matches(state);
  }

  /**
   * Check if touch is ongoing.
   *
   * @returns {boolean}
   */
  isTouchOngoing() {
    return this.touchMachine.matches("ongoing");
  }

  /**
   * Check if touch has ended.
   *
   * @returns {boolean}
   */
  isTouchEnded() {
    return this.touchMachine.matches("ended");
  }

  /**
   * Check if long-running operation is active.
   *
   * @returns {boolean}
   */
  isLongRunning() {
    return this.longRunningMachine.matches("true");
  }

  /**
   * Get position machine's current value.
   *
   * @returns {string}
   */
  getPositionValue() {
    return this.positionMachine.current;
  }
}
