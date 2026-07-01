import { EVENTS } from "../state-machine-events";

export default class ElementsState {
  #machine;

  constructor(machine) {
    this.#machine = machine;
  }

  get isReady() {
    return this.#machine.matches("true");
  }

  get isNotReady() {
    return this.#machine.matches("false");
  }

  markRegistered() {
    this.#machine.send(EVENTS.ELEMENTS_REGISTERED);
  }

  reset() {
    this.#machine.send(EVENTS.RESET);
  }
}
