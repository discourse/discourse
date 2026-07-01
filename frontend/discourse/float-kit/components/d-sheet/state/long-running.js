import { EVENTS } from "../state-machine-events";

export default class LongRunningState {
  #machine;

  constructor(machine) {
    this.#machine = machine;
  }

  get isActive() {
    return this.#machine.matches("true");
  }

  get isInactive() {
    return this.#machine.matches("false");
  }

  start() {
    this.#machine.send(EVENTS.TO_TRUE);
  }

  end() {
    this.#machine.send(EVENTS.TO_FALSE);
  }
}
