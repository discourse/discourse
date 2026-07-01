import { EVENTS } from "../state-machine-events";

export default class SkipState {
  #openingMachine;
  #closingMachine;

  constructor(openingMachine, closingMachine) {
    this.#openingMachine = openingMachine;
    this.#closingMachine = closingMachine;
  }

  get isOpening() {
    return this.#openingMachine.matches("true");
  }

  get isClosing() {
    return this.#closingMachine.matches("true");
  }

  enableOpening() {
    this.#openingMachine.send(EVENTS.TO_TRUE);
  }

  disableOpening() {
    this.#openingMachine.send(EVENTS.TO_FALSE);
  }

  enableClosing() {
    this.#closingMachine.send(EVENTS.TO_TRUE);
  }

  disableClosing() {
    this.#closingMachine.send(EVENTS.TO_FALSE);
  }
}
