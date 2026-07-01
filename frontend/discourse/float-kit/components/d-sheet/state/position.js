import { EVENTS } from "../state-machine-events";

export default class PositionState {
  #machine;

  constructor(machine) {
    this.#machine = machine;
  }

  get isOut() {
    return this.#machine.matches("out");
  }

  get isFront() {
    return this.#machine.matches("front");
  }

  get isCovered() {
    return this.#machine.matches("covered");
  }

  get isFrontOpening() {
    return this.#machine.matches("front.status:opening");
  }

  get isFrontClosing() {
    return this.#machine.matches("front.status:closing");
  }

  get isFrontIdle() {
    return this.#machine.matches("front.status:idle");
  }

  get isCoveredIdle() {
    return this.#machine.matches("covered.status:idle");
  }

  get isIdle() {
    return (
      this.isOut ||
      this.#machine.matches("front.status:idle") ||
      this.#machine.matches("covered.status:idle")
    );
  }

  goOut() {
    this.#machine.send(EVENTS.GO_OUT);
  }

  advance() {
    this.#machine.send(EVENTS.NEXT);
  }

  goToFrontIdle() {
    this.#machine.send(EVENTS.GOTO_FRONT);
  }

  goToCoveredIdle() {
    this.#machine.send(EVENTS.GOTO_IDLE);
  }

  readyToGoFront(skipOpening) {
    this.#machine.send(EVENTS.READY_TO_GO_FRONT, { skipOpening });
  }

  readyToGoOut() {
    this.#machine.send(EVENTS.READY_TO_GO_OUT);
  }

  get current() {
    return this.#machine.current;
  }

  matches(state) {
    return this.#machine.matches(state);
  }
}
