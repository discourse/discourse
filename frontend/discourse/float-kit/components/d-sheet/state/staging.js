import { EVENTS } from "../state-machine-events";

export default class StagingState {
  #machine;
  #openness;

  constructor(machine, opennessNamespace) {
    this.#machine = machine;
    this.#openness = opennessNamespace;
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
    this.#machine.send(EVENTS.OPEN_PREPARED, {
      opennessState: this.#openness.current,
    });
  }

  actuallyClose(skipClosing = false) {
    this.#machine.send(EVENTS.ACTUALLY_CLOSE, {
      opennessState: this.#openness.current,
      skipClosing,
    });
  }

  actuallyStep() {
    this.#machine.send(EVENTS.ACTUALLY_STEP, {
      opennessState: this.#openness.current,
    });
  }

  advance() {
    this.#machine.send(EVENTS.NEXT);
  }

  goDown() {
    this.#machine.send(EVENTS.GO_DOWN, {
      opennessState: this.#openness.current,
    });
  }

  goUp() {
    this.#machine.send(EVENTS.GO_UP, {
      opennessState: this.#openness.current,
    });
  }

  get current() {
    return this.#machine.current;
  }
}
