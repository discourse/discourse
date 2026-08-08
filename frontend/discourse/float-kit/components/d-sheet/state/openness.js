import { EVENTS } from "../state-machine-events";

export default class OpennessState {
  #machine;

  constructor(machine) {
    this.#machine = machine;
  }

  get isOpen() {
    return this.#machine.current === "open";
  }

  get isClosing() {
    return this.#machine.current === "closing";
  }

  get isOpening() {
    return (
      this.#machine.current === "opening" ||
      this.#machine.matches("closed.status:preparing-opening") ||
      this.#machine.matches("closed.status:preparing-open")
    );
  }

  get isClosed() {
    return this.#machine.current === "closed";
  }

  get isClosedPending() {
    return this.#machine.matches("closed.status:pending");
  }

  get isClosedSafeToUnmount() {
    return this.#machine.matches("closed.status:safe-to-unmount");
  }

  get isScrollOngoing() {
    return this.#machine.matches("open.scroll:ongoing");
  }

  get isScrollEnded() {
    return this.#machine.matches("open.scroll:ended");
  }

  get isSwipeOngoing() {
    return this.#machine.matches("open.swipe:ongoing");
  }

  get isMoveOngoing() {
    return this.#machine.matches("open.move:ongoing");
  }

  scrollStart() {
    if (!this.isScrollOngoing) {
      this.#machine.send(EVENTS.SCROLL_START);
    }
  }

  scrollEnd() {
    if (this.isScrollOngoing) {
      this.#machine.send(EVENTS.SCROLL_END);
    }
  }

  swipeStart() {
    this.#machine.send(EVENTS.SWIPE_START);
  }

  swipeEnd() {
    this.#machine.send(EVENTS.SWIPE_END);
  }

  completeAnimation() {
    this.#machine.send(EVENTS.NEXT);
  }

  moveStart() {
    this.#machine.send(EVENTS.MOVE_START);
  }

  moveEnd() {
    this.#machine.send(EVENTS.MOVE_END);
  }

  beginStep(detent) {
    this.#machine.send({ type: EVENTS.STEP, detent });
  }

  readyToOpen(skipOpening) {
    this.#machine.send({ type: EVENTS.READY_TO_OPEN, skipOpening });
  }

  flushComplete() {
    this.#machine.send({
      machine: "openness:closed.status",
      type: EVENTS.FLUSH_COMPLETE,
    });
  }

  send(messageOrType, context) {
    this.#machine.send(messageOrType, context);
  }

  get current() {
    return this.#machine.current;
  }

  get lastProcessedMessage() {
    return this.#machine.lastProcessedMessage;
  }
}
