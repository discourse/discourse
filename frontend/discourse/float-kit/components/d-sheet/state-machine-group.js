import { tracked } from "@glimmer/tracking";
import StateMachine from "./state-machine";

export default class StateMachineGroup {
  @tracked version = 0;
  #machines = new Map();
  #guards;

  constructor(machineDefinitions, options = {}) {
    this.#guards = options.guards || {};

    for (const def of machineDefinitions) {
      const machine = new StateMachine(
        {
          initial: def.initial,
          states: def.states,
          silentOnly: def.silentOnly,
        },
        def.initial,
        { guards: this.#guards, parentGroup: this, machineName: def.name }
      );
      this.#machines.set(def.name, machine);
    }
  }

  hasMachine(name) {
    return this.#machines.has(name);
  }

  getMachine(name) {
    return this.#machines.get(name);
  }

  send(message, context = {}) {
    let anyTransitioned = false;
    for (const machine of this.#machines.values()) {
      if (machine.send(message, context)) {
        anyTransitioned = true;
      }
    }
    if (anyTransitioned) {
      this.version++;
    }
  }

  toStrings() {
    // Trigger reactivity
    void this.version;

    const result = [];
    for (const [name, machine] of this.#machines) {
      for (const state of machine.toStrings()) {
        result.push(`${name}:${state}`);
      }
    }
    return result;
  }

  transitionTo(target) {
    const colonIndex = target.indexOf(":");
    if (colonIndex === -1) {
      return;
    }

    const machineName = target.substring(0, colonIndex);
    const statePath = target.substring(colonIndex + 1);

    const machine = this.#machines.get(machineName);
    if (machine) {
      machine.transitionToState(statePath);
      this.version++;
    }
  }
}
