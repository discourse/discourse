import ElementsState from "./state/elements";
import LongRunningState from "./state/long-running";
import OpennessState from "./state/openness";
import PositionState from "./state/position";
import SkipState from "./state/skip";
import StagingState from "./state/staging";
import StuckState from "./state/stuck";
import TouchState from "./state/touch";
import { EVENTS, MACHINE_NAMES } from "./state-machine-events";
import StateMachineGroup from "./state-machine-group";
import { GUARDS, POSITION_MACHINES, SHEET_MACHINES } from "./states";

export default class StateHelper {
  #sheetMachines = new StateMachineGroup(SHEET_MACHINES, { guards: GUARDS });
  #positionMachines = new StateMachineGroup(POSITION_MACHINES, {
    guards: GUARDS,
  });

  constructor() {
    this.openness = new OpennessState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.OPENNESS)
    );
    this.staging = new StagingState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.STAGING),
      this.openness
    );
    this.position = new PositionState(
      this.#positionMachines.getMachine(MACHINE_NAMES.POSITION)
    );
    this.touch = new TouchState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.SCROLL_CONTAINER_TOUCH)
    );
    this.stuck = new StuckState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.FRONT_STUCK),
      this.#sheetMachines.getMachine(MACHINE_NAMES.BACK_STUCK)
    );
    this.elements = new ElementsState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.ELEMENTS_READY)
    );
    this.skip = new SkipState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_OPENING),
      this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_CLOSING)
    );
    this.longRunning = new LongRunningState(
      this.#sheetMachines.getMachine(MACHINE_NAMES.LONG_RUNNING)
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

  stepAnimation() {
    this.staging.actuallyStep();
  }

  subscribe(machineName, options) {
    const machine = this.#getMachine(machineName);
    return machine.subscribe(options);
  }

  #getMachine(name) {
    const mapping = {
      openness: () => this.#sheetMachines.getMachine(MACHINE_NAMES.OPENNESS),
      staging: () => this.#sheetMachines.getMachine(MACHINE_NAMES.STAGING),
      position: () => this.#positionMachines.getMachine(MACHINE_NAMES.POSITION),
      touch: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.SCROLL_CONTAINER_TOUCH),
      longRunning: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.LONG_RUNNING),
      skipOpening: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_OPENING),
      skipClosing: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_CLOSING),
      backStuck: () => this.#sheetMachines.getMachine(MACHINE_NAMES.BACK_STUCK),
      frontStuck: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.FRONT_STUCK),
      elementsReady: () =>
        this.#sheetMachines.getMachine(MACHINE_NAMES.ELEMENTS_READY),
    };
    return mapping[name]?.();
  }

  cleanup() {
    for (const machine of [
      this.#sheetMachines.getMachine(MACHINE_NAMES.OPENNESS),
      this.#sheetMachines.getMachine(MACHINE_NAMES.STAGING),
      this.#positionMachines.getMachine(MACHINE_NAMES.POSITION),
      this.#sheetMachines.getMachine(MACHINE_NAMES.SCROLL_CONTAINER_TOUCH),
      this.#sheetMachines.getMachine(MACHINE_NAMES.LONG_RUNNING),
      this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_OPENING),
      this.#sheetMachines.getMachine(MACHINE_NAMES.SKIP_CLOSING),
      this.#sheetMachines.getMachine(MACHINE_NAMES.BACK_STUCK),
      this.#sheetMachines.getMachine(MACHINE_NAMES.FRONT_STUCK),
      this.#sheetMachines.getMachine(MACHINE_NAMES.ELEMENTS_READY),
    ]) {
      machine.cleanup();
    }
  }

  sendToPosition(message, context = {}) {
    return this.#positionMachines
      .getMachine(MACHINE_NAMES.POSITION)
      .send(message, context);
  }

  advancePositionAuto() {
    this.#positionMachines.getMachine(MACHINE_NAMES.POSITION).send("");
  }

  flushClosedStatus() {
    this.openness.flushComplete();
  }

  broadcastOpen() {
    this.#sheetMachines.send({ type: EVENTS.OPEN });
  }
}
