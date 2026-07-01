import { EVENTS } from "../state-machine-events";

export default class StuckState {
  #frontMachine;
  #backMachine;

  constructor(frontMachine, backMachine) {
    this.#frontMachine = frontMachine;
    this.#backMachine = backMachine;
  }

  get isFront() {
    return this.#frontMachine.matches("true");
  }

  get isBack() {
    return this.#backMachine.matches("true");
  }

  get isEither() {
    return this.isFront || this.isBack;
  }

  startFront() {
    this.#frontMachine.send(EVENTS.STUCK_START);
  }

  endFront() {
    this.#frontMachine.send(EVENTS.STUCK_END);
  }

  startBack() {
    this.#backMachine.send(EVENTS.STUCK_START);
  }

  endBack() {
    this.#backMachine.send(EVENTS.STUCK_END);
  }

  endAll() {
    if (this.isFront) {
      this.endFront();
    }
    if (this.isBack) {
      this.endBack();
    }
  }
}
