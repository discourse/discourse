function asArray(value) {
  return Array.isArray(value) ? value : [value];
}

function statePathParts(statePath) {
  const parts = [];
  let fullPath = "";

  for (const segment of statePath.split(".")) {
    fullPath = fullPath ? `${fullPath}.${segment}` : segment;
    const separatorIndex = fullPath.lastIndexOf(":");

    parts.push({
      machinePath: fullPath.slice(0, separatorIndex),
      statePath: fullPath,
    });
  }

  return parts;
}

export default class StateMachineDefinition {
  #guards;
  #machines = new Map();
  #states = new Map();
  #rootMachinePaths = [];

  constructor(machineDefinitions, guards = {}) {
    this.#guards = guards;

    for (const definition of asArray(machineDefinitions)) {
      const machine = this.#compileMachine(definition);
      this.#rootMachinePaths.push(machine.path);
    }

    this.#validateTransitions();
  }

  initialStatePaths() {
    return this.#buildStatePaths(new Map());
  }

  transition(previousStatePaths, message) {
    const targetsByMachine = new Map();
    let transitioned = false;

    for (const statePath of previousStatePaths) {
      const state = this.#states.get(statePath);

      if (
        !state ||
        (message.machine && message.machine !== state.machinePath)
      ) {
        continue;
      }

      const target = this.#selectTarget(
        state,
        state.config.messages?.[message.type],
        previousStatePaths,
        message
      );

      if (!target) {
        continue;
      }

      transitioned = true;

      for (const part of statePathParts(target)) {
        const existingTarget = targetsByMachine.get(part.machinePath);

        if (existingTarget && existingTarget !== part.statePath) {
          throw new Error(
            `Conflicting transitions for state machine '${part.machinePath}'`
          );
        }

        targetsByMachine.set(part.machinePath, part.statePath);
      }
    }

    if (!transitioned) {
      return {
        enteredStatePaths: [],
        exitedStatePaths: [],
        previousStatePaths,
        reactive: false,
        transitioned: false,
      };
    }

    const previousStatesByMachine = new Map(
      previousStatePaths.map((statePath) => [
        this.#states.get(statePath).machinePath,
        statePath,
      ])
    );
    const nextStatePaths = this.#buildStatePaths(
      targetsByMachine,
      previousStatesByMachine
    );
    const previousStateSet = new Set(previousStatePaths);
    const nextStateSet = new Set(nextStatePaths);
    const enteredStatePaths = nextStatePaths.filter(
      (statePath) => !previousStateSet.has(statePath)
    );
    const exitedStatePaths = previousStatePaths.filter(
      (statePath) => !nextStateSet.has(statePath)
    );
    const changedStatePaths = [...exitedStatePaths, ...enteredStatePaths];

    return {
      enteredStatePaths,
      exitedStatePaths,
      nextStatePaths,
      previousStatePaths,
      reactive: changedStatePaths.some(
        (statePath) => this.#states.get(statePath).reactive
      ),
      transitioned: true,
    };
  }

  matches(statePaths, statePath) {
    return statePaths.some(
      (currentStatePath) =>
        currentStatePath === statePath ||
        (currentStatePath.startsWith(statePath) &&
          currentStatePath.charAt(statePath.length) === ".")
    );
  }

  stateValue(statePaths, machinePath) {
    const statePath = statePaths.find(
      (path) => this.#states.get(path).machinePath === machinePath
    );

    return statePath ? this.#states.get(statePath).name : null;
  }

  scopedStatePaths(statePaths, machinePath) {
    const prefix = `${machinePath}:`;
    const selectedStatePath = statePaths.find(
      (statePath) => this.#states.get(statePath).machinePath === machinePath
    );

    if (!selectedStatePath) {
      return [];
    }

    return statePaths
      .filter(
        (statePath) =>
          statePath === selectedStatePath ||
          statePath.startsWith(`${selectedStatePath}.`)
      )
      .map((statePath) => statePath.slice(prefix.length));
  }

  resolveStatePath(machinePath, state) {
    const statePath = state.startsWith(`${machinePath}:`)
      ? state
      : `${machinePath}:${state}`;

    if (!this.#states.has(statePath)) {
      throw new Error(`Unknown state '${statePath}'`);
    }

    return statePath;
  }

  hasMachine(machinePath) {
    return this.#machines.has(machinePath);
  }

  #compileMachine(definition, parentStatePath = null) {
    if (!definition?.name || !definition.states || !definition.initial) {
      throw new Error(
        "State machine definitions require a name, initial state, and states"
      );
    }

    if (/[.:]/.test(definition.name)) {
      throw new Error(`Invalid state machine name '${definition.name}'`);
    }

    const machinePath = parentStatePath
      ? `${parentStatePath}.${definition.name}`
      : definition.name;

    if (this.#machines.has(machinePath)) {
      throw new Error(`Duplicate state machine '${machinePath}'`);
    }

    const machine = {
      initial: definition.initial,
      path: machinePath,
      statePaths: new Map(),
    };
    this.#machines.set(machinePath, machine);

    for (const [stateName, config] of Object.entries(definition.states)) {
      if (/[.:]/.test(stateName)) {
        throw new Error(
          `Invalid state name '${stateName}' in '${machinePath}'`
        );
      }

      const statePath = `${machinePath}:${stateName}`;
      const state = {
        childMachinePaths: [],
        config,
        machinePath,
        name: stateName,
        path: statePath,
        reactive: !definition.silentOnly,
      };

      machine.statePaths.set(stateName, statePath);
      this.#states.set(statePath, state);

      if (config.machines) {
        for (const childDefinition of asArray(config.machines)) {
          const childMachine = this.#compileMachine(childDefinition, statePath);
          state.childMachinePaths.push(childMachine.path);
        }
      }
    }

    if (!machine.statePaths.has(machine.initial)) {
      throw new Error(
        `Unknown initial state '${machine.initial}' in '${machinePath}'`
      );
    }

    return machine;
  }

  #validateTransitions() {
    for (const state of this.#states.values()) {
      for (const transitions of Object.values(state.config.messages || {})) {
        for (const transition of asArray(transitions)) {
          const target =
            typeof transition === "string" ? transition : transition.target;
          const guard =
            typeof transition === "string" ? null : transition.guard;

          if (!target) {
            throw new Error(
              `Transition from '${state.path}' requires a target`
            );
          }

          this.#resolveTarget(state, target);

          if (typeof guard === "string" && !this.#guards[guard]) {
            throw new Error(`Unknown guard '${guard}' in '${state.path}'`);
          }
        }
      }
    }
  }

  #selectTarget(state, transitions, previousStatePaths, message) {
    if (!transitions) {
      return null;
    }

    for (const transition of asArray(transitions)) {
      if (typeof transition === "string") {
        return this.#resolveTarget(state, transition);
      }

      const guard =
        typeof transition.guard === "string"
          ? this.#guards[transition.guard]
          : transition.guard;

      if (!guard || guard(previousStatePaths, message)) {
        return this.#resolveTarget(state, transition.target);
      }
    }

    return null;
  }

  #resolveTarget(state, target) {
    const statePath = target.includes(":")
      ? target
      : `${state.machinePath}:${target}`;

    if (!this.#states.has(statePath)) {
      throw new Error(
        `Unknown transition target '${statePath}' from '${state.path}'`
      );
    }

    return statePath;
  }

  #buildStatePaths(targetsByMachine, previousStatesByMachine = new Map()) {
    const statePaths = [];

    const appendMachineState = (machinePath) => {
      const machine = this.#machines.get(machinePath);
      const statePath =
        targetsByMachine.get(machinePath) ||
        previousStatesByMachine.get(machinePath) ||
        machine.statePaths.get(machine.initial);
      const state = this.#states.get(statePath);

      if (!state || state.machinePath !== machinePath) {
        throw new Error(
          `Invalid active state '${statePath}' for '${machinePath}'`
        );
      }

      statePaths.push(statePath);

      for (const childMachinePath of state.childMachinePaths) {
        appendMachineState(childMachinePath);
      }
    };

    for (const machinePath of this.#rootMachinePaths) {
      appendMachineState(machinePath);
    }

    return statePaths;
  }
}
