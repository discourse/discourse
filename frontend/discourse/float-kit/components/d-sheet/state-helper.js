import ElementsState from "./state/elements";
import LongRunningState from "./state/long-running";
import OpennessState from "./state/openness";
import PositionState from "./state/position";
import SkipState from "./state/skip";
import StagingState from "./state/staging";
import StuckState from "./state/stuck";
import TouchState from "./state/touch";
import StateMachine from "./state-machine";
import { EVENTS, MACHINE_NAMES } from "./state-machine-events";
import { GUARDS, POSITION_MACHINES, SHEET_MACHINES } from "./states";

export default class StateHelper {
  #positionMachine = new StateMachine(POSITION_MACHINES, { guards: GUARDS });
  #sheetMachine = new StateMachine(SHEET_MACHINES, { guards: GUARDS });
  #selectors = new Map();

  constructor() {
    for (const name of [
      MACHINE_NAMES.STAGING,
      MACHINE_NAMES.LONG_RUNNING,
      MACHINE_NAMES.SKIP_OPENING,
      MACHINE_NAMES.SKIP_CLOSING,
      MACHINE_NAMES.OPENNESS,
      MACHINE_NAMES.SCROLL_CONTAINER_TOUCH,
      MACHINE_NAMES.ELEMENTS_READY,
    ]) {
      this.#selectors.set(name, this.#sheetMachine.select(name));
    }

    for (const name of [MACHINE_NAMES.BACK_STUCK, MACHINE_NAMES.FRONT_STUCK]) {
      this.#selectors.set(
        name,
        this.#sheetMachine.select(name, { includeSilentUpdates: true })
      );
    }

    this.#selectors.set(
      MACHINE_NAMES.POSITION,
      this.#positionMachine.select(MACHINE_NAMES.POSITION)
    );

    this.openness = new OpennessState(
      this.#selectors.get(MACHINE_NAMES.OPENNESS)
    );
    this.staging = new StagingState(this.#selectors.get(MACHINE_NAMES.STAGING));
    this.position = new PositionState(
      this.#selectors.get(MACHINE_NAMES.POSITION)
    );
    this.touch = new TouchState(
      this.#selectors.get(MACHINE_NAMES.SCROLL_CONTAINER_TOUCH)
    );
    this.stuck = new StuckState(
      this.#selectors.get(MACHINE_NAMES.FRONT_STUCK),
      this.#selectors.get(MACHINE_NAMES.BACK_STUCK)
    );
    this.elements = new ElementsState(
      this.#selectors.get(MACHINE_NAMES.ELEMENTS_READY)
    );
    this.skip = new SkipState(
      this.#selectors.get(MACHINE_NAMES.SKIP_OPENING),
      this.#selectors.get(MACHINE_NAMES.SKIP_CLOSING)
    );
    this.longRunning = new LongRunningState(
      this.#selectors.get(MACHINE_NAMES.LONG_RUNNING)
    );
  }

  beginEnterAnimation(skipOpening = false) {
    this.staging.openPrepared();
    this.position.readyToGoFront(skipOpening);
  }

  beginExitAnimation(skipClosing = false) {
    this.staging.actuallyClose(skipClosing);
    this.position.readyToGoOut();
  }

  beginImmediateClose(skipClosing = true) {
    this.staging.actuallyClose(skipClosing);
  }

  stepAnimation(detent, behavior) {
    this.staging.actuallyStep(detent, behavior);
  }

  subscribe(machineName, options) {
    const machine = this.#getMachine(machineName);
    return machine.subscribe(options);
  }

  #getMachine(name) {
    const mapping = {
      openness: MACHINE_NAMES.OPENNESS,
      staging: MACHINE_NAMES.STAGING,
      position: MACHINE_NAMES.POSITION,
      touch: MACHINE_NAMES.SCROLL_CONTAINER_TOUCH,
      longRunning: MACHINE_NAMES.LONG_RUNNING,
      skipOpening: MACHINE_NAMES.SKIP_OPENING,
      skipClosing: MACHINE_NAMES.SKIP_CLOSING,
      backStuck: MACHINE_NAMES.BACK_STUCK,
      frontStuck: MACHINE_NAMES.FRONT_STUCK,
      elementsReady: MACHINE_NAMES.ELEMENTS_READY,
    };
    return this.#selectors.get(mapping[name]);
  }

  cleanup() {
    this.#sheetMachine.cleanup();
    this.#positionMachine.cleanup();
  }

  sendToPosition(message, context = {}) {
    return this.#selectors
      .get(MACHINE_NAMES.POSITION)
      .sendUnscoped(message, context);
  }

  advanceClosedStatus() {
    this.openness.advanceClosedStatus();
  }

  broadcastOpen() {
    this.#sheetMachine.send({ type: EVENTS.OPEN });
  }
}
