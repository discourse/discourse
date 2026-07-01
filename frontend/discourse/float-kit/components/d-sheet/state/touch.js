import { EVENTS } from "../state-machine-events";

export default class TouchState {
  #machine;

  constructor(machine) {
    this.#machine = machine;
  }

  get isOngoing() {
    return this.#machine.matches("ongoing");
  }

  get isEnded() {
    return this.#machine.matches("ended");
  }

  start() {
    this.#machine.send(EVENTS.TOUCH_START);
  }

  end() {
    this.#machine.send(EVENTS.TOUCH_END);
  }
}
