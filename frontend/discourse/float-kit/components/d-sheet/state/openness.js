/**
 * Namespace for openness state machine (main open/close lifecycle).
 * Includes nested scroll, move, and swipe states.
 */
export default class OpennessState {
  /**
   * The underlying state machine driving openness transitions.
   *
   * @type {import("../state-machine").default}
   */
  #machine;

  /**
   * @param {import("../state-machine").default} machine - The openness state machine instance
   */
  constructor(machine) {
    this.#machine = machine;
  }

  /**
   * Whether the sheet is fully open.
   *
   * @type {boolean}
   */
  get isOpen() {
    return this.#machine.current === "open";
  }

  /**
   * Whether the sheet is in the closing transition.
   *
   * @type {boolean}
   */
  get isClosing() {
    return this.#machine.current === "closing";
  }

  /**
   * Whether the sheet is in the opening transition or preparing to open.
   *
   * @type {boolean}
   */
  get isOpening() {
    return (
      this.#machine.current === "opening" ||
      this.#machine.matches("closed.status:preparing-opening") ||
      this.#machine.matches("closed.status:preparing-open")
    );
  }

  /**
   * Whether the sheet is fully closed.
   *
   * @type {boolean}
   */
  get isClosed() {
    return this.#machine.current === "closed";
  }

  /**
   * Whether the sheet is closed and pending further action.
   *
   * @type {boolean}
   */
  get isClosedPending() {
    return this.#machine.matches("closed.status:pending");
  }

  /**
   * Whether the sheet is closed and safe to unmount from the DOM.
   *
   * @type {boolean}
   */
  get isClosedSafeToUnmount() {
    return this.#machine.matches("closed.status:safe-to-unmount");
  }

  /**
   * Whether content scrolling is actively ongoing.
   *
   * @type {boolean}
   */
  get isScrollOngoing() {
    return this.#machine.matches("open.scroll:ongoing");
  }

  /**
   * Whether content scrolling has ended.
   *
   * @type {boolean}
   */
  get isScrollEnded() {
    return this.#machine.matches("open.scroll:ended");
  }

  /**
   * Whether a swipe gesture is actively ongoing.
   *
   * @type {boolean}
   */
  get isSwipeOngoing() {
    return this.#machine.matches("open.swipe:ongoing");
  }

  /**
   * Whether a move gesture is actively ongoing.
   *
   * @type {boolean}
   */
  get isMoveOngoing() {
    return this.#machine.matches("open.move:ongoing");
  }

  /**
   * Signals the start of a scroll interaction, guarded to avoid duplicate sends.
   *
   * @returns {void}
   */
  scrollStart() {
    if (!this.isScrollOngoing) {
      this.#machine.send("SCROLL_START");
    }
  }

  /**
   * Signals the end of a scroll interaction, guarded to only send when scrolling.
   *
   * @returns {void}
   */
  scrollEnd() {
    if (this.isScrollOngoing) {
      this.#machine.send("SCROLL_END");
    }
  }

  /**
   * Signals the start of a swipe gesture.
   *
   * @returns {void}
   */
  swipeStart() {
    this.#machine.send("SWIPE_START");
  }

  /**
   * Signals the end of a swipe gesture.
   *
   * @returns {void}
   */
  swipeEnd() {
    this.#machine.send("SWIPE_END");
  }

  /**
   * Signals that an animation has completed, advancing to the next state.
   *
   * @returns {void}
   */
  completeAnimation() {
    this.#machine.send("NEXT");
  }

  /**
   * Signals the start of a move gesture.
   *
   * @returns {void}
   */
  moveStart() {
    this.#machine.send("MOVE_START");
  }

  /**
   * Signals the end of a move gesture.
   *
   * @returns {void}
   */
  moveEnd() {
    this.#machine.send("MOVE_END");
  }

  /**
   * Begins a step transition to a specific detent position.
   *
   * @param {number} detent - The target detent index to step to
   * @returns {void}
   */
  beginStep(detent) {
    this.#machine.send({ type: "STEP", detent });
  }

  /**
   * Signals that the sheet is ready to open.
   *
   * @param {boolean} skipOpening - Whether to skip the opening animation
   * @returns {void}
   */
  readyToOpen(skipOpening) {
    this.#machine.send({ type: "READY_TO_OPEN", skipOpening });
  }

  /**
   * Forwards an arbitrary message to the underlying state machine.
   *
   * @param {string | {type: string}} messageOrType - Message type string or message object
   * @param {Object} [context] - Optional context data for guards
   * @returns {void}
   */
  send(messageOrType, context) {
    this.#machine.send(messageOrType, context);
  }

  /**
   * The current state of the openness machine.
   *
   * @type {string}
   */
  get current() {
    return this.#machine.current;
  }

  /**
   * The last message processed by the openness machine.
   *
   * @type {{type: string} | null}
   */
  get lastProcessedMessage() {
    return this.#machine.lastProcessedMessage;
  }
}
