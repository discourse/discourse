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

  get isClosedFlushing() {
    return (
      this.#machine.matches("closed.status:flushing-to-preparing-open") ||
      this.#machine.matches("closed.status:flushing-to-preparing-opening")
    );
  }

  get isScrollOngoing() {
    return this.#machine.matches("open.scroll:ongoing");
  }

  get isScrollEnded() {
    return this.#machine.matches("open.scroll:ended");
  }

  get areScrollEndedAfterPaintEffectsRun() {
    return (
      this.isScrollEnded &&
      this.#machine.matches("open.scroll:ended.afterPaintEffectsRun:true")
    );
  }

  get isSwipeOngoing() {
    return this.#machine.matches("open.swipe:ongoing");
  }

  get isMoveOngoing() {
    return this.#machine.matches("open.move:ongoing");
  }

  scrollStart() {
    if (!this.isScrollOngoing) {
      this.#machine.send({
        machine: "openness:open.scroll",
        type: EVENTS.SCROLL_START,
      });
    }
  }

  scrollEnd() {
    if (this.isScrollOngoing) {
      this.#machine.send({
        machine: "openness:open.scroll",
        type: EVENTS.SCROLL_END,
      });
    }
  }

  markScrollEndedAfterPaintEffectsRun() {
    this.#machine.send({
      machine: "openness:open.scroll:ended.afterPaintEffectsRun",
      type: EVENTS.OCCURRED,
    });
  }

  swipeStart() {
    this.#machine.send({
      machine: "openness:open.swipe",
      type: EVENTS.SWIPE_START,
    });
  }

  swipeEnd() {
    this.#machine.send({
      machine: "openness:open.swipe",
      type: EVENTS.SWIPE_END,
    });
  }

  swipeReset() {
    this.#machine.send({
      machine: "openness:open.swipe",
      type: EVENTS.SWIPE_RESET,
    });
  }

  completeAnimation() {
    this.#machine.send(EVENTS.NEXT);
  }

  moveStart() {
    this.#machine.send({
      machine: "openness:open.move",
      type: EVENTS.MOVE_START,
    });
  }

  moveEnd() {
    this.#machine.send({
      machine: "openness:open.move",
      type: EVENTS.MOVE_END,
    });
  }

  beginStep(detent) {
    this.#machine.sendUnscoped({ type: EVENTS.STEP, detent });
  }

  readyToOpen(skipOpening) {
    this.#machine.send({ type: EVENTS.READY_TO_OPEN, skipOpening });
  }

  advanceClosedStatus() {
    this.#machine.send({
      machine: "openness:closed.status",
      type: "",
    });
  }

  send(messageOrType, context) {
    this.#machine.sendUnscoped(messageOrType, context);
  }

  get current() {
    return this.#machine.current;
  }

  get lastProcessedMessage() {
    return this.#machine.lastProcessedMessage;
  }
}
