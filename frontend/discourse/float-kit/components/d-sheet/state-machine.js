import { tracked } from "@glimmer/tracking";
import { trackedObject } from "@ember/reactive/collections";
import { cancel, schedule } from "@ember/runloop";

const AUTOMATIC_TRANSITION = "";
const TIMING = {
  IMMEDIATE: "immediate",
  BEFORE_PAINT: "before-paint",
  AFTER_PAINT: "after-paint",
};
const TYPE = {
  ENTER: "enter",
  EXIT: "exit",
};

function asArray(value) {
  return Array.isArray(value) ? value : [value];
}

class StateMachine {
  @tracked current;
  definition;
  nestedMachines = trackedObject();
  lastProcessedMessage = null;
  #messageQueue = [];
  #isProcessingQueue = false;
  #subscriptions = [];
  #entryActions = [];
  #exitActions = [];
  #stateConfigCache = new Map();
  #guards = {};
  #currentStateMachines = null;
  #silentMachines = new Set();
  #parentGroup = null;
  #machineName = null;
  #isDestroyed = false;
  #scheduledRunLoopTasks = new Set();
  #scheduledAnimationFrames = new Set();

  constructor(definition, initialState, options = {}) {
    this.definition = definition;
    this.current = initialState;
    this.#guards = options.guards || {};
    this.#parentGroup = options.parentGroup || null;
    this.#machineName = options.machineName || null;
    this.#initializeNestedMachines(this.current);
    this.#processAutomaticTransitions();
  }

  send(message, context = {}) {
    if (this.#isDestroyed) {
      return false;
    }

    const normalizedMessage =
      typeof message === "string" ? { type: message } : message;

    this.#messageQueue.push({ message: normalizedMessage, context });

    if (!this.#isProcessingQueue) {
      return this.#processQueue();
    }

    return true;
  }

  matches(state) {
    if (this.current === state) {
      return true;
    }

    if (state.includes(":")) {
      return this.#matchesNestedMachineState(state);
    }

    return (
      this.current.startsWith(state) &&
      this.current.charAt(state.length) === "."
    );
  }

  toStrings() {
    const strings = [this.current];
    const parentState = this.current.split(".")[0];

    for (const [machineName, machineState] of Object.entries(
      this.nestedMachines
    )) {
      if (machineState) {
        strings.push(`${parentState}.${machineName}:${machineState}`);
      }
    }

    return strings;
  }

  subscribe({
    timing,
    state,
    transition = null,
    callback,
    guard = true,
    type = TYPE.ENTER,
  }) {
    if (this.#isDestroyed) {
      return () => {};
    }

    const id = Symbol();
    const subscription = { id, timing, state, transition, callback, guard };

    if (type === TYPE.EXIT) {
      this.#exitActions.push(subscription);
    } else if (timing === TIMING.IMMEDIATE) {
      this.#entryActions.push(subscription);
    } else {
      this.#subscriptions.push(subscription);
    }

    return () => this.#unsubscribe(id);
  }

  cleanup() {
    if (this.#isDestroyed) {
      return;
    }

    this.#isDestroyed = true;

    for (const task of this.#scheduledRunLoopTasks) {
      cancel(task);
    }
    this.#scheduledRunLoopTasks.clear();

    for (const frame of this.#scheduledAnimationFrames) {
      cancelAnimationFrame(frame);
    }
    this.#scheduledAnimationFrames.clear();

    this.#subscriptions = [];
    this.#entryActions = [];
    this.#exitActions = [];
    this.#messageQueue = [];
    this.#isProcessingQueue = false;
  }

  getStateConfig(statePath) {
    if (this.#stateConfigCache.has(statePath)) {
      return this.#stateConfigCache.get(statePath);
    }

    const config = this.#resolveStateConfig(statePath);
    this.#stateConfigCache.set(statePath, config);
    return config;
  }

  getNestedMachineState(machineName) {
    return this.nestedMachines[machineName] || null;
  }

  #resolveStateConfig(statePath) {
    const parts = statePath.split(".");
    let config = this.definition.states[parts[0]];

    if (!config) {
      return null;
    }

    for (let i = 1; i < parts.length; i++) {
      if (config.states?.[parts[i]]) {
        config = config.states[parts[i]];
      } else if (config.machines) {
        const machineDef = config.machines.find((m) => m.name === parts[i]);
        if (machineDef && i + 1 < parts.length) {
          const machineState = parts[i + 1];
          if (machineDef.states?.[machineState]) {
            config = machineDef.states[machineState];
            i++;
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    }

    return config;
  }

  #unsubscribe(id) {
    this.#subscriptions = this.#subscriptions.filter((s) => s.id !== id);
    this.#entryActions = this.#entryActions.filter((s) => s.id !== id);
    this.#exitActions = this.#exitActions.filter((s) => s.id !== id);
  }

  #initializeNestedMachines(statePath) {
    const stateConfig = this.getStateConfig(statePath);
    this.#silentMachines.clear();

    if (stateConfig?.machines) {
      const machinesArray = asArray(stateConfig.machines);

      this.#currentStateMachines = machinesArray;
      for (const machineDef of machinesArray) {
        this.nestedMachines[machineDef.name] = machineDef.initial;
        if (machineDef.silentOnly) {
          this.#silentMachines.add(machineDef.name);
        }
      }
    } else {
      this.#currentStateMachines = null;
    }
  }

  #isSilentMachine(machineName) {
    return this.#silentMachines.has(machineName);
  }

  #setNestedMachineState(machineName, stateName) {
    this.nestedMachines[machineName] = stateName;
  }

  #getParentState(statePath) {
    const parts = statePath.split(".");
    return parts.length > 1 ? parts[0] : null;
  }

  #processQueue() {
    if (this.#messageQueue.length === 0) {
      this.#isProcessingQueue = false;
      return false;
    }

    this.#isProcessingQueue = true;
    let anyTransitioned = false;

    while (this.#messageQueue.length > 0) {
      const { message, context } = this.#messageQueue.shift();
      const result = this.#processMessage(message, context);

      this.lastProcessedMessage = message;

      if (result.transitioned) {
        anyTransitioned = true;
        if (result.silent) {
          this.#notifyImmediateSubscribers(
            message,
            result.enteredStates,
            result.exitedStates
          );
        } else {
          this.#notifySubscribers(
            message,
            result.enteredStates,
            result.exitedStates
          );
        }
      }
    }

    this.#isProcessingQueue = false;
    return anyTransitioned;
  }

  #processMessage(message, context = {}) {
    const enrichedMessage = { ...message, ...context };
    const previousState = this.current;
    const previousNestedStates = { ...this.nestedMachines };

    const mainStateResult = this.#tryMainStateTransition(enrichedMessage);
    if (mainStateResult) {
      this.#processAutomaticTransitions();
      this.#processNestedMachinesSilently(enrichedMessage);

      const { entered, exited } = this.#calculateStateChanges(
        previousState,
        previousNestedStates
      );
      return {
        transitioned: true,
        enteredStates: entered,
        exitedStates: exited,
        silent: false,
      };
    }

    const nestedResult = this.#tryNestedMachineTransition(enrichedMessage);
    if (nestedResult) {
      const { entered, exited } = this.#calculateStateChanges(
        previousState,
        previousNestedStates,
        { includeUnchangedCurrentState: !nestedResult.silent }
      );
      return {
        transitioned: true,
        enteredStates: entered,
        exitedStates: exited,
        silent: nestedResult.silent,
      };
    }

    return {
      transitioned: false,
      enteredStates: [],
      exitedStates: [],
      silent: false,
    };
  }

  #tryMainStateTransition(message) {
    const messageType = message.type;
    const currentStateConfig = this.getStateConfig(this.current);

    let transitions = currentStateConfig?.messages?.[messageType];

    if (!transitions) {
      const parentState = this.#getParentState(this.current);
      if (parentState) {
        const parentConfig = this.getStateConfig(parentState);
        transitions = parentConfig?.messages?.[messageType];
      }
    }

    if (!transitions) {
      return false;
    }

    return this.#tryTransitions(transitions, message, (target) =>
      this.#transitionToState(target)
    );
  }

  #tryNestedMachineTransition(message) {
    const messageType = message.type;
    const currentStateConfig = this.getStateConfig(this.current);

    if (!currentStateConfig?.machines) {
      return null;
    }

    const machinesArray = asArray(currentStateConfig.machines);

    for (const machineDef of machinesArray) {
      const machineName = machineDef.name;
      const currentMachineState =
        this.getNestedMachineState(machineName) || machineDef.initial;
      const machineStateConfig = machineDef.states?.[currentMachineState];

      if (!machineStateConfig?.messages?.[messageType]) {
        continue;
      }

      const transitioned = this.#tryTransitions(
        machineStateConfig.messages[messageType],
        message,
        (target) => {
          if (this.#isCrossLevelTransition(target, machineDef)) {
            this.#transitionToState(target);
          } else {
            this.#setNestedMachineState(machineName, target);
          }
        }
      );

      if (transitioned) {
        this.#processNestedMachineAutomaticTransitions(machineName);
        return { silent: this.#isSilentMachine(machineName) };
      }
    }

    return null;
  }

  #tryTransitions(transitions, message, onSuccess) {
    const transitionList = asArray(transitions);

    for (const transition of transitionList) {
      if (typeof transition === "string") {
        onSuccess(transition);
        return true;
      }

      if (transition.guard) {
        const previousStates = this.#parentGroup
          ? this.#parentGroup.toStrings()
          : this.toStrings();
        const guardPassed = this.#checkGuard(
          transition.guard,
          previousStates,
          message
        );
        if (!guardPassed) {
          continue;
        }
      }

      if (transition.target) {
        onSuccess(transition.target);
        return true;
      }
    }

    return false;
  }

  #checkGuard(guardName, previousStates, message) {
    const guardFn = this.#guards[guardName];
    return guardFn ? guardFn(previousStates, message) : true;
  }

  transitionToState(targetState) {
    this.#transitionToState(targetState);
  }

  #transitionToState(targetState) {
    // Check for machine prefix when part of a group (e.g., "position:front.status:idle")
    if (this.#parentGroup) {
      const colonIndex = targetState.indexOf(":");
      if (colonIndex !== -1) {
        const potentialMachineName = targetState.substring(0, colonIndex);
        // If prefix matches a different machine in the group, delegate
        if (
          this.#parentGroup.hasMachine(potentialMachineName) &&
          potentialMachineName !== this.#machineName
        ) {
          this.#parentGroup.transitionTo(targetState);
          return;
        }
        // If prefix matches our own name, strip it and continue
        if (potentialMachineName === this.#machineName) {
          targetState = targetState.substring(colonIndex + 1);
        }
      }
    }

    const colonIndex = targetState.indexOf(":");

    if (colonIndex !== -1) {
      this.#transitionToNestedMachinePath(targetState);
    } else {
      this.#transitionToStatePath(targetState);
    }
  }

  #transitionToNestedMachinePath(targetState) {
    const dotIndex = targetState.indexOf(".");
    const mainState = targetState.substring(0, dotIndex);
    const rest = targetState.substring(dotIndex + 1);

    this.current = mainState;

    const stateConfig = this.getStateConfig(mainState);
    const newMachines = stateConfig?.machines || null;

    if (this.#machinesAreDifferent(this.#currentStateMachines, newMachines)) {
      this.nestedMachines = trackedObject();
      this.#initializeNestedMachines(mainState);
    }

    const machineColonIndex = rest.indexOf(":");
    const machineName = rest.substring(0, machineColonIndex);
    const machineState = rest.substring(machineColonIndex + 1);
    this.#setNestedMachineState(machineName, machineState);
  }

  #transitionToStatePath(targetState) {
    this.current = targetState;

    const stateConfig = this.getStateConfig(targetState);
    const newMachines = stateConfig?.machines || null;

    if (this.#machinesAreDifferent(this.#currentStateMachines, newMachines)) {
      this.nestedMachines = trackedObject();
      this.#initializeNestedMachines(targetState);
    }
  }

  #machinesAreDifferent(oldMachines, newMachines) {
    if (oldMachines === newMachines) {
      return false;
    }
    if (!oldMachines || !newMachines) {
      return true;
    }

    const oldMachineList = asArray(oldMachines);
    const newMachineList = asArray(newMachines);

    if (oldMachineList.length !== newMachineList.length) {
      return true;
    }

    for (let i = 0; i < oldMachineList.length; i++) {
      if (oldMachineList[i].name !== newMachineList[i].name) {
        return true;
      }
    }
    return false;
  }

  #isCrossLevelTransition(target, machineDef) {
    return !machineDef.states?.[target];
  }

  #processAutomaticTransitions() {
    const currentStateConfig = this.getStateConfig(this.current);

    if (this.#processMainStateAutomaticTransition(currentStateConfig)) {
      return;
    }

    this.#processNestedMachinesAutomaticTransitions(currentStateConfig);
  }

  #processMainStateAutomaticTransition(currentStateConfig) {
    if (!currentStateConfig?.messages?.[AUTOMATIC_TRANSITION]) {
      return false;
    }

    const previousState = this.current;
    const previousNestedStates = { ...this.nestedMachines };

    const transitioned = this.#tryTransitions(
      currentStateConfig.messages[AUTOMATIC_TRANSITION],
      { type: AUTOMATIC_TRANSITION },
      (target) => this.#transitionToState(target)
    );

    if (transitioned) {
      const { entered, exited } = this.#calculateStateChanges(
        previousState,
        previousNestedStates
      );
      this.#notifySubscribers({ type: AUTOMATIC_TRANSITION }, entered, exited);
      this.#processAutomaticTransitions();
      return true;
    }

    return false;
  }

  #processNestedMachinesAutomaticTransitions(currentStateConfig) {
    if (!currentStateConfig?.machines) {
      return;
    }

    const machinesArray = asArray(currentStateConfig.machines);

    for (const machineDef of machinesArray) {
      const machineName = machineDef.name;
      const currentMachineState =
        this.getNestedMachineState(machineName) || machineDef.initial;
      const machineStateConfig = machineDef.states?.[currentMachineState];

      if (!machineStateConfig?.messages?.[AUTOMATIC_TRANSITION]) {
        continue;
      }

      const previousState = this.current;
      const previousNestedStates = { ...this.nestedMachines };

      const transitioned = this.#tryTransitions(
        machineStateConfig.messages[AUTOMATIC_TRANSITION],
        { type: AUTOMATIC_TRANSITION },
        (target) => this.#setNestedMachineState(machineName, target)
      );

      if (transitioned) {
        const { entered, exited } = this.#calculateStateChanges(
          previousState,
          previousNestedStates
        );
        if (!this.#isSilentMachine(machineName)) {
          this.#notifySubscribers(
            { type: AUTOMATIC_TRANSITION },
            entered,
            exited
          );
        }
        this.#processAutomaticTransitions();
        return;
      }
    }
  }

  #processNestedMachineAutomaticTransitions(machineName) {
    const currentStateConfig = this.getStateConfig(this.current);
    if (!currentStateConfig?.machines) {
      return;
    }

    const machinesArray = asArray(currentStateConfig.machines);

    const machineDef = machinesArray.find((m) => m.name === machineName);
    if (!machineDef) {
      return;
    }

    const currentMachineState =
      this.getNestedMachineState(machineName) || machineDef.initial;
    const machineStateConfig = machineDef.states?.[currentMachineState];

    if (machineStateConfig?.messages?.[AUTOMATIC_TRANSITION]) {
      const transitioned = this.#tryTransitions(
        machineStateConfig.messages[AUTOMATIC_TRANSITION],
        { type: AUTOMATIC_TRANSITION },
        (target) => this.#setNestedMachineState(machineName, target)
      );

      if (transitioned) {
        this.#processNestedMachineAutomaticTransitions(machineName);
      }
    }
  }

  #processNestedMachinesSilently(message) {
    const messageType = message.type;
    const currentStateConfig = this.getStateConfig(this.current);

    if (!currentStateConfig?.machines) {
      return;
    }

    const machinesArray = asArray(currentStateConfig.machines);

    for (const machineDef of machinesArray) {
      if (!machineDef.silentOnly) {
        continue;
      }

      const machineName = machineDef.name;
      const currentMachineState =
        this.getNestedMachineState(machineName) || machineDef.initial;
      const machineStateConfig = machineDef.states?.[currentMachineState];

      if (machineStateConfig?.messages?.[messageType]) {
        this.#tryTransitions(
          machineStateConfig.messages[messageType],
          message,
          (target) => {
            if (!this.#isCrossLevelTransition(target, machineDef)) {
              this.#setNestedMachineState(machineName, target);
            }
          }
        );
      }
    }
  }

  #matchesNestedMachineState(state) {
    const dotIndex = state.indexOf(".");
    const colonIndex = state.indexOf(":");

    if (dotIndex === -1 || colonIndex === -1) {
      return false;
    }

    const parentState = state.substring(0, dotIndex);
    const machineName = state.substring(dotIndex + 1, colonIndex);
    const machineState = state.substring(colonIndex + 1);

    const isInParentState =
      this.current === parentState ||
      this.current.startsWith(`${parentState}.`);

    if (!isInParentState) {
      return false;
    }

    const currentMachineState = this.getNestedMachineState(machineName);

    if (currentMachineState === machineState) {
      return true;
    }

    return (
      currentMachineState?.startsWith(machineState) &&
      currentMachineState?.charAt(machineState.length) === "."
    );
  }

  #calculateStateChanges(
    previousState,
    previousNestedStates,
    { includeUnchangedCurrentState = true } = {}
  ) {
    const entered = [];
    const exited = [];

    const parentState = this.current.split(".")[0];
    const prevParentState = previousState.split(".")[0];

    if (includeUnchangedCurrentState || this.current !== previousState) {
      entered.push(this.current);
    }

    if (this.current !== previousState) {
      exited.push(previousState);
    }

    for (const [machineName, machineState] of Object.entries(
      this.nestedMachines
    )) {
      const prevMachineState = previousNestedStates[machineName];
      if (prevMachineState !== machineState) {
        entered.push(`${parentState}.${machineName}:${machineState}`);
        if (prevMachineState) {
          exited.push(`${prevParentState}.${machineName}:${prevMachineState}`);
        }
      }
    }

    if (parentState !== prevParentState) {
      for (const [machineName, machineState] of Object.entries(
        previousNestedStates
      )) {
        if (machineState) {
          exited.push(`${prevParentState}.${machineName}:${machineState}`);
        }
      }
    }

    return { entered, exited };
  }

  #notifySubscribers(message, enteredStates, exitedStates) {
    this.#notifyImmediateSubscribers(message, enteredStates, exitedStates);
    this.#dispatchTimedSubscriptions(message);
  }

  #notifyImmediateSubscribers(message, enteredStates, exitedStates) {
    this.#dispatchExitActions(message, exitedStates);
    this.#dispatchEntryActions(message, enteredStates);
  }

  #dispatchExitActions(message, exitedStates) {
    for (const sub of this.#exitActions) {
      const wasExited = this.#didExitState(sub, exitedStates);
      const transitionMatches = this.#matchesTransition(sub, message);
      const guardPasses =
        typeof sub.guard === "function" ? sub.guard() : sub.guard;

      if (wasExited && transitionMatches && guardPasses) {
        sub.callback(message);
      }
    }
  }

  #dispatchEntryActions(message, enteredStates) {
    for (const sub of this.#entryActions) {
      const wasEntered = this.#didEnterState(sub, enteredStates);
      const transitionMatches = this.#matchesTransition(sub, message);
      const guardPasses =
        typeof sub.guard === "function" ? sub.guard() : sub.guard;

      if (wasEntered && transitionMatches && guardPasses) {
        sub.callback(message);
      }
    }
  }

  #dispatchTimedSubscriptions(message) {
    let beforePaintSubs = null;
    let afterPaintSubs = null;

    for (const sub of this.#subscriptions) {
      if (!this.#evaluateSubscriptionConditions(sub, message)) {
        continue;
      }

      if (sub.timing === TIMING.BEFORE_PAINT) {
        if (!beforePaintSubs) {
          beforePaintSubs = [];
        }
        beforePaintSubs.push(sub);
      } else if (sub.timing === TIMING.AFTER_PAINT) {
        if (!afterPaintSubs) {
          afterPaintSubs = [];
        }
        afterPaintSubs.push(sub);
      }
    }

    if (beforePaintSubs) {
      this.#scheduleAfterRender(() => {
        for (const sub of beforePaintSubs) {
          if (this.#evaluateSubscriptionConditions(sub, message)) {
            sub.callback(message);
          }
        }
      });
    }

    if (afterPaintSubs) {
      this.#scheduleAfterRender(() => {
        this.#scheduleAnimationFrame(() => {
          for (const sub of afterPaintSubs) {
            if (this.#evaluateSubscriptionConditions(sub, message)) {
              sub.callback(message);
            }
          }
        });
      });
    }
  }

  #scheduleAfterRender(callback) {
    let task;
    task = schedule("afterRender", () => {
      this.#scheduledRunLoopTasks.delete(task);

      if (!this.#isDestroyed) {
        callback();
      }
    });
    this.#scheduledRunLoopTasks.add(task);
  }

  #scheduleAnimationFrame(callback) {
    const frame = requestAnimationFrame(() => {
      this.#scheduledAnimationFrames.delete(frame);

      if (!this.#isDestroyed) {
        callback();
      }
    });
    this.#scheduledAnimationFrames.add(frame);
  }

  #evaluateSubscriptionConditions(sub, message) {
    let stateMatches;
    if (Array.isArray(sub.state)) {
      stateMatches = sub.state.some((s) => this.matches(s));
    } else {
      stateMatches = this.matches(sub.state);
    }
    const transitionMatches = this.#matchesTransition(sub, message);
    const guardPasses =
      typeof sub.guard === "function" ? sub.guard() : sub.guard;
    return stateMatches && transitionMatches && guardPasses;
  }

  #matchesTransition(sub, message) {
    if (!sub.transition) {
      return true;
    }

    const messageType = message?.type;
    if (!messageType) {
      return false;
    }

    if (Array.isArray(sub.transition)) {
      return sub.transition.includes(messageType);
    }

    return sub.transition === messageType;
  }

  #didEnterState(sub, enteredStates) {
    return asArray(sub.state).some((state) => enteredStates.includes(state));
  }

  #didExitState(sub, exitedStates) {
    return asArray(sub.state).some((state) => exitedStates.includes(state));
  }
}

export default StateMachine;
