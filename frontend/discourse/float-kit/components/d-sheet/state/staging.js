import { EVENTS } from "../state-machine-events";

export default class StagingState {
  #machine;

  constructor(machine) {
    this.#machine = machine;
  }

  get isNone() {
    return this.#machine.current === "none";
  }

  get isOpening() {
    return this.#machine.current === "opening";
  }

  get isOpen() {
    return this.#machine.current === "open";
  }

  get isStepping() {
    return this.#machine.current === "stepping";
  }

  get isClosing() {
    return this.#machine.current === "closing";
  }

  get isGoingDown() {
    return this.#machine.current === "going-down";
  }

  get isGoingUp() {
    return this.#machine.current === "going-up";
  }

  get isAnimating() {
    return this.#machine.current !== "none";
  }

  matches(state) {
    return this.#machine.matches(state);
  }

  openPrepared() {
    this.#machine.send(EVENTS.OPEN_PREPARED);
  }

  actuallyClose(skipClosing = false) {
    this.#machine.send(EVENTS.ACTUALLY_CLOSE, { skipClosing });
  }

  actuallyStep(detent, behavior) {
    this.#machine.send({ type: EVENTS.ACTUALLY_STEP, detent, behavior });
  }

  advance() {
    this.#machine.send(EVENTS.NEXT);
  }

  goDown() {
    this.#machine.send(EVENTS.GO_DOWN);
  }

  goUp() {
    this.#machine.send(EVENTS.GO_UP);
  }

  get current() {
    return this.#machine.current;
  }
}
