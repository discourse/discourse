import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import { TrackedObject } from "@ember-compat/tracked-built-ins";

/**
 * @typedef {Object} Subscription
 * @property {Symbol} id - Unique identifier for the subscription
 * @property {string} timing - When to invoke callback ("immediate", "before-paint", "after-paint")
 * @property {string|string[]} state - State pattern(s) to match
 * @property {function(Object): void} callback - Function to call when state matches
 * @property {function(): boolean|boolean} guard - Guard condition
 */

/**
 * @typedef {Object} QueuedMessage
 * @property {{type: string}} message - The message to process
 * @property {Object} context - Context data for guards
 */

/**
 * @typedef {Object} StateDefinition
 * @property {string} initial - Initial state
 * @property {Object<string, Object>} states - Map of state names to configurations
 * @property {boolean} [silentOnly] - If true, state changes don't trigger reactive updates
 */

/**
 * @typedef {Object} StateMachineOptions
 * @property {Object<string, function(string[], Object): boolean>} [guards] - Guard functions for transitions
 */

/**
 * @typedef {Object} TransitionResult
 * @property {boolean} transitioned - Whether a transition occurred
 * @property {string[]} enteredStates - States that were entered
 * @property {string[]} exitedStates - States that were exited
 * @property {boolean} silent - Whether the transition was silent
 */

const DEBUG = {
  enabled: false,
  log(...args) {
    if (this.enabled) {
      // eslint-disable-next-line no-console
      console.log("[StateMachine]", ...args);
    }
  },
};

if (typeof window !== "undefined") {
  window.debugSheetsStateMachine = () => {
    DEBUG.enabled = true;
    DEBUG.log("Debug logging enabled");
  };
}

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

/**
 * Hierarchical state machine with support for nested machines and subscriptions.
 * Uses Glimmer tracking for automatic reactivity when state changes.
 *
 * @class StateMachine
 *
 * @example
 * const machine = new StateMachine(
 *   {
 *     initial: "idle",
 *     states: {
 *       idle: { messages: { START: "running" } },
 *       running: { messages: { STOP: "idle" } }
 *     }
 *   },
 *   "idle"
 * );
 *
 * machine.send("START");
 * machine.matches("running"); // true
 */
class StateMachine {
  /**
   * Current state of the machine.
   *
   * @type {string}
   */
  @tracked current;

  /**
   * The state machine definition.
   *
   * @type {StateDefinition}
   */
  definition;

  /**
   * Context data used by guards.
   *
   * @type {Object<string, *>}
   */
  context = {};

  /**
   * Tracked object containing states of nested machines.
   *
   * @type {TrackedObject<string, string>}
   */
  nestedMachines = new TrackedObject();

  /**
   * The last message that was processed.
   *
   * @type {{type: string}|null}
   */
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

  /**
   * Parent group if this machine is part of a StateMachineGroup.
   * @type {Object|null}
   */
  #parentGroup = null;

  /**
   * Name of this machine within its parent group.
   * @type {string|null}
   */
  #machineName = null;

  /**
   * @param {Object} definition - State machine definition with states and transitions
   * @param {string} initialState - Initial state path (e.g., "closed.safe-to-unmount")
   * @param {StateMachineOptions} [options] - Optional configuration including guards
   */
  constructor(definition, initialState, options = {}) {
    this.definition = definition;
    this.current = initialState;
    this.#guards = options.guards || {};
    this.#parentGroup = options.parentGroup || null;
    this.#machineName = options.machineName || null;
    this.#initializeNestedMachines(this.current);
    this.#processAutomaticTransitions();
  }

  /**
   * Send a message to the state machine.
   *
   * @param {string|Object} message - Message type string or object with type property
   * @param {Object} [context={}] - Context data for guards
   * @returns {boolean} Whether any transition occurred
   *
   * @example
   * machine.send("OPEN");
   * machine.send({ type: "STEP", detent: 2 });
   */
  send(message, context = {}) {
    const normalizedMessage =
      typeof message === "string" ? { type: message } : message;

    DEBUG.log(
      `send: ${normalizedMessage.type}, current: ${this.current}, context:`,
      context
    );

    this.#messageQueue.push({ message: normalizedMessage, context });

    if (!this.#isProcessingQueue) {
      return this.#processQueue();
    }

    return true;
  }

  /**
   * Check if the machine is in a specific state.
   *
   * @param {string} state - State pattern to match
   * @returns {boolean} Whether the machine matches the state
   *
   * @example
   * machine.matches("open");                    // exact match
   * machine.matches("closed");                  // matches "closed.pending"
   * machine.matches("front.status:idle");       // nested machine state
   */
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

  /**
   * Returns an array of all current state strings including nested machine states.
   *
   * @returns {string[]} Array of state strings
   *
   * @example
   * // Returns ["open", "open.scroll:ended", "open.move:ended"]
   * machine.toStrings();
   */
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

  /**
   * Subscribe to state changes with timing control.
   *
   * @param {Object} options - Subscription options
   * @param {string} options.timing - "immediate", "before-paint", or "after-paint"
   * @param {string|string[]} options.state - State pattern(s) to match
   * @param {Function} options.callback - Function to call when state matches
   * @param {Function|boolean} [options.guard] - Optional guard condition
   * @param {string} [options.type] - "enter" (default) or "exit"
   * @returns {Function} Unsubscribe function
   *
   * @example
   * const unsubscribe = machine.subscribe({
   *   timing: "immediate",
   *   state: "open",
   *   callback: (message) => console.log("Opened!", message),
   *   guard: () => someCondition
   * });
   *
   * // Later: unsubscribe();
   */
  subscribe({ timing, state, callback, guard = true, type = TYPE.ENTER }) {
    const id = Symbol();
    const subscription = { id, timing, state, callback, guard };

    if (type === TYPE.EXIT) {
      this.#exitActions.push(subscription);
    } else if (timing === TIMING.IMMEDIATE) {
      this.#entryActions.push(subscription);
    } else {
      this.#subscriptions.push(subscription);
    }

    return () => this.#unsubscribe(id);
  }

  /**
   * Remove all subscriptions from this machine.
   */
  cleanup() {
    this.#subscriptions = [];
    this.#entryActions = [];
    this.#exitActions = [];
  }

  /**
   * Update the machine context used by guards.
   *
   * @param {Object} newContext - New context values to merge
   */
  updateContext(newContext) {
    this.context = { ...this.context, ...newContext };
  }

  /**
   * Get the configuration for a given state path.
   *
   * @param {string} statePath - Dot-notation state path
   * @returns {Object|null} State configuration or null if not found
   */
  getStateConfig(statePath) {
    if (this.#stateConfigCache.has(statePath)) {
      return this.#stateConfigCache.get(statePath);
    }

    const config = this.#resolveStateConfig(statePath);
    this.#stateConfigCache.set(statePath, config);
    return config;
  }

  /**
   * Get nested machine definition for a state.
   *
   * @param {string} stateName - Parent state name
   * @param {string} machineName - Nested machine name
   * @returns {Object|null} Machine definition or null
   */
  getNestedMachine(stateName, machineName) {
    const stateConfig = this.getStateConfig(stateName);
    if (!stateConfig?.machines) {
      return null;
    }

    // Normalize to array if single object
    const machinesArray = Array.isArray(stateConfig.machines)
      ? stateConfig.machines
      : [stateConfig.machines];

    return machinesArray.find((m) => m.name === machineName) || null;
  }

  /**
   * Get the current state of a nested machine.
   *
   * @param {string} machineName - Nested machine name
   * @returns {string|null} Current state or null
   */
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
      // Normalize to array if single object
      const machinesArray = Array.isArray(stateConfig.machines)
        ? stateConfig.machines
        : [stateConfig.machines];

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
        if (!result.silent) {
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

  /**
   * @param {Object} message
   * @param {Object} context
   * @returns {TransitionResult}
   */
  #processMessage(message, context = {}) {
    // Merge context into message for guards
    const enrichedMessage = { ...message, ...context };
    const previousState = this.current;
    const previousNestedStates = { ...this.nestedMachines };

    DEBUG.log(
      `processMessage: type=${message.type}, previousState=${previousState}, nestedStates:`,
      previousNestedStates
    );

    const mainStateResult = this.#tryMainStateTransition(
      enrichedMessage,
      context
    );
    if (mainStateResult) {
      this.#processAutomaticTransitions();
      this.#processNestedMachinesSilently(enrichedMessage, context);

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

    const nestedResult = this.#tryNestedMachineTransition(
      enrichedMessage,
      context
    );
    if (nestedResult) {
      const { entered, exited } = this.#calculateStateChanges(
        previousState,
        previousNestedStates
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

  #tryMainStateTransition(message, context) {
    const messageType = message.type;
    const currentStateConfig = this.getStateConfig(this.current);

    let transitions = currentStateConfig?.messages?.[messageType];
    DEBUG.log(
      `processMessage: checking main state transitions, found:`,
      transitions ? "yes" : "no"
    );

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

    return this.#tryTransitions(transitions, message, context, (target) =>
      this.#transitionToState(target)
    );
  }

  #tryNestedMachineTransition(message, context) {
    const messageType = message.type;
    const currentStateConfig = this.getStateConfig(this.current);

    if (!currentStateConfig?.machines) {
      return null;
    }

    // Normalize to array if single object
    const machinesArray = Array.isArray(currentStateConfig.machines)
      ? currentStateConfig.machines
      : [currentStateConfig.machines];

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
        context,
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

  #tryTransitions(transitions, message, context, onSuccess) {
    const transitionList = Array.isArray(transitions)
      ? transitions
      : [transitions];

    for (const transition of transitionList) {
      if (typeof transition === "string") {
        DEBUG.log(`tryTransitions: direct target "${transition}"`);
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
        DEBUG.log(
          `tryTransitions: guard "${transition.guard}" -> ${guardPassed}`
        );
        if (!guardPassed) {
          continue;
        }
      }

      if (transition.target) {
        DEBUG.log(`tryTransitions: target "${transition.target}"`);
        onSuccess(transition.target);
        return true;
      }
    }

    DEBUG.log(`tryTransitions: no valid transition found`);
    return false;
  }

  #checkGuard(guardName, previousStates, message) {
    const guardFn = this.#guards[guardName];
    return guardFn ? guardFn(previousStates, message) : true;
  }

  /**
   * Transition to a specific state. Public method for StateMachineGroup.
   *
   * @param {string} targetState - Target state path
   */
  transitionToState(targetState) {
    this.#transitionToState(targetState);
  }

  #transitionToState(targetState) {
    const previousState = this.current;
    DEBUG.log(`transitionToState: ${previousState} -> ${targetState}`);

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
          DEBUG.log(`transitionToState: delegating to ${potentialMachineName}`);
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

    DEBUG.log(`transitionToState: nested MACHINE path, mainState=${mainState}`);

    this.current = mainState;

    const stateConfig = this.getStateConfig(mainState);
    const newMachines = stateConfig?.machines || null;

    if (this.#machinesAreDifferent(this.#currentStateMachines, newMachines)) {
      DEBUG.log(`transitionToState: reinitializing nested machines`);
      this.nestedMachines = new TrackedObject();
      this.#initializeNestedMachines(mainState);
    }

    const machineColonIndex = rest.indexOf(":");
    const machineName = rest.substring(0, machineColonIndex);
    const machineState = rest.substring(machineColonIndex + 1);
    DEBUG.log(
      `transitionToState: setting nested machine ${machineName}=${machineState}`
    );
    this.#setNestedMachineState(machineName, machineState);
  }

  #transitionToStatePath(targetState) {
    this.current = targetState;

    const stateConfig = this.getStateConfig(targetState);
    const newMachines = stateConfig?.machines || null;

    if (this.#machinesAreDifferent(this.#currentStateMachines, newMachines)) {
      this.nestedMachines = new TrackedObject();
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
    if (oldMachines.length !== newMachines.length) {
      return true;
    }
    for (let i = 0; i < oldMachines.length; i++) {
      if (oldMachines[i].name !== newMachines[i].name) {
        return true;
      }
    }
    return false;
  }

  #isCrossLevelTransition(target, machineDef) {
    if (machineDef.states?.[target]) {
      return false;
    }
    return true;
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
      {},
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

    // Normalize to array if single object
    const machinesArray = Array.isArray(currentStateConfig.machines)
      ? currentStateConfig.machines
      : [currentStateConfig.machines];

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
        {},
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

    // Normalize to array if single object
    const machinesArray = Array.isArray(currentStateConfig.machines)
      ? currentStateConfig.machines
      : [currentStateConfig.machines];

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
        {},
        (target) => this.#setNestedMachineState(machineName, target)
      );

      if (transitioned) {
        this.#processNestedMachineAutomaticTransitions(machineName);
      }
    }
  }

  #processNestedMachinesSilently(message, context) {
    const messageType = message.type;
    const currentStateConfig = this.getStateConfig(this.current);

    DEBUG.log(`processNestedMachinesSilently: message=${messageType}`);

    if (!currentStateConfig?.machines) {
      DEBUG.log(`processNestedMachinesSilently: no machines to process`);
      return;
    }

    // Normalize to array if single object
    const machinesArray = Array.isArray(currentStateConfig.machines)
      ? currentStateConfig.machines
      : [currentStateConfig.machines];

    for (const machineDef of machinesArray) {
      if (!machineDef.silentOnly) {
        continue;
      }

      const machineName = machineDef.name;
      const currentMachineState =
        this.getNestedMachineState(machineName) || machineDef.initial;
      const machineStateConfig = machineDef.states?.[currentMachineState];

      DEBUG.log(
        `processNestedMachinesSilently: checking silentOnly machine "${machineName}", currentState="${currentMachineState}"`
      );

      if (machineStateConfig?.messages?.[messageType]) {
        DEBUG.log(
          `processNestedMachinesSilently: "${machineName}" handles "${messageType}"`
        );
        this.#tryTransitions(
          machineStateConfig.messages[messageType],
          message,
          context,
          (target) => {
            DEBUG.log(
              `processNestedMachinesSilently: "${machineName}" transitioning to "${target}"`
            );
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

  #calculateStateChanges(previousState, previousNestedStates) {
    const entered = [];
    const exited = [];

    const parentState = this.current.split(".")[0];
    const prevParentState = previousState.split(".")[0];

    DEBUG.log(
      `calculateStateChanges: previousState=${previousState}, currentState=${this.current}`
    );

    entered.push(this.current);

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

    DEBUG.log(`calculateStateChanges: entered=`, entered, `exited=`, exited);
    return { entered, exited };
  }

  #notifySubscribers(message, enteredStates, exitedStates) {
    DEBUG.log(
      `notifySubscribers: message=${message.type}, enteredStates=`,
      enteredStates,
      `exitedStates=`,
      exitedStates
    );
    DEBUG.log(
      `notifySubscribers: ${this.#exitActions.length} exit actions, ${this.#entryActions.length} entry actions, ${this.#subscriptions.length} subscriptions`
    );

    this.#dispatchExitActions(message, exitedStates);
    this.#dispatchEntryActions(message, enteredStates);
    this.#dispatchTimedSubscriptions(message);
  }

  #dispatchExitActions(message, exitedStates) {
    for (const sub of this.#exitActions) {
      const wasExited = this.#didExitState(sub, exitedStates);
      const guardPasses =
        typeof sub.guard === "function" ? sub.guard() : sub.guard;

      DEBUG.log(
        `notifySubscribers: exit action for state="${sub.state}", wasExited=${wasExited}, guardPasses=${guardPasses}`
      );
      if (wasExited && guardPasses) {
        DEBUG.log(`notifySubscribers: FIRING exit callback for "${sub.state}"`);
        sub.callback(message);
      }
    }
  }

  #dispatchEntryActions(message, enteredStates) {
    for (const sub of this.#entryActions) {
      const wasEntered = this.#didEnterState(sub, enteredStates);
      const guardPasses =
        typeof sub.guard === "function" ? sub.guard() : sub.guard;

      DEBUG.log(
        `notifySubscribers: entry action for state="${sub.state}", wasEntered=${wasEntered}, guardPasses=${guardPasses}`
      );
      if (wasEntered && guardPasses) {
        DEBUG.log(
          `notifySubscribers: FIRING entry callback for "${sub.state}"`
        );
        sub.callback(message);
      }
    }
  }

  #dispatchTimedSubscriptions(message) {
    let afterPaintSubs = null;

    for (const sub of this.#subscriptions) {
      if (!this.#evaluateSubscriptionConditions(sub)) {
        continue;
      }

      if (sub.timing === TIMING.BEFORE_PAINT) {
        sub.callback(message);
      } else if (sub.timing === TIMING.AFTER_PAINT) {
        if (!afterPaintSubs) {
          afterPaintSubs = [];
        }
        afterPaintSubs.push(sub);
      }
    }

    if (afterPaintSubs) {
      schedule("afterRender", () => {
        for (const sub of afterPaintSubs) {
          if (this.#evaluateSubscriptionConditions(sub)) {
            sub.callback(message);
          }
        }
      });
    }
  }

  #evaluateSubscriptionConditions(sub) {
    let stateMatches;
    if (Array.isArray(sub.state)) {
      stateMatches = sub.state.some((s) => this.matches(s));
    } else {
      stateMatches = this.matches(sub.state);
    }
    const guardPasses =
      typeof sub.guard === "function" ? sub.guard() : sub.guard;
    return stateMatches && guardPasses;
  }

  #didEnterState(sub, enteredStates) {
    const subStates = Array.isArray(sub.state) ? sub.state : [sub.state];

    for (const subState of subStates) {
      const found = enteredStates.includes(subState);
      DEBUG.log(
        `didEnterState: checking "${subState}" in`,
        enteredStates,
        `-> ${found}`
      );
      if (found) {
        return true;
      }
    }
    return false;
  }

  #didExitState(sub, exitedStates) {
    const subStates = Array.isArray(sub.state) ? sub.state : [sub.state];

    for (const subState of subStates) {
      if (exitedStates.includes(subState)) {
        return true;
      }
    }
    return false;
  }
}

export default StateMachine;
