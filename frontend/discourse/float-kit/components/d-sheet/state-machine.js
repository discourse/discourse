import { schedule } from "@ember/runloop";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { tracked } from "@glimmer/tracking";

/**
 * Hierarchical state machine with support for nested machines and subscriptions.
 * Uses Glimmer tracking for automatic reactivity when state changes.
 *
 * @class StateMachine
 */
/**
 * @typedef {Object} Subscription
 * @property {Symbol} id - Unique identifier for the subscription
 * @property {"immediate"|"before-paint"|"after-paint"} timing - When to invoke callback
 * @property {string} state - State pattern to match
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
 */

class StateMachine {
  /** @type {string} */
  @tracked current;

  /** @type {StateDefinition} */
  definition;

  /** @type {Object<string, *>} */
  context = {};

  /** @type {TrackedObject<string, string>} */
  nestedMachines = new TrackedObject();

  /** @type {QueuedMessage[]} */
  messageQueue = [];

  /** @type {boolean} */
  isProcessingQueue = false;

  /** @type {{type: string}|null} */
  lastMessageTreated = null;

  /** @type {Subscription[]} */
  subscriptions = [];

  /** @type {Subscription[]} */
  entryActions = [];

  /** @type {Map<string, Object|null>} */
  stateConfigCache = new Map();

  /**
   * Guard functions for state transitions.
   * Each guard receives (message, context) and returns a boolean.
   *
   * @type {Object<string, function(Object, Object): boolean>}
   */
  guards = {
    isClosed: () => this.context.isClosed,
    isClosedAndSkipOpening: () =>
      this.context.isClosed && this.context.skipOpening,
    notSkipOpening: (_, context) =>
      !this.context.skipOpening && !context.skipOpening,
    notSkipClosing: (_, context) =>
      !this.context.skipClosing && !context.skipClosing,
    skipOpening: (_, context) =>
      this.context.skipOpening || context.skipOpening,
    skipClosing: (_, context) =>
      this.context.skipClosing || context.skipClosing,
    isSafeToUnmount: (_, context) =>
      context.opennessState?.includes("closed.safe-to-unmount"),
    isSafeToUnmountAndNotSkipOpening: (_, context) =>
      context.opennessState?.includes("closed.safe-to-unmount") &&
      !this.context.skipOpening &&
      !context.skipOpening,
  };

  /**
   * @param {Object} definition - State machine definition with states and transitions
   * @param {string} initialState - Initial state path (e.g., "closed.safe-to-unmount")
   */
  constructor(definition, initialState) {
    this.definition = definition;
    this.current = initialState;
    this.initializeNestedMachines(this.current);
  }

  /**
   * Subscribe to state changes with timing control.
   *
   * @param {Object} options
   * @param {string} options.timing - "immediate" | "before-paint" | "after-paint"
   * @param {string} options.state - State pattern to match
   * @param {Function} options.callback - Function to call when state matches
   * @param {Function|boolean} [options.guard] - Optional guard condition
   * @returns {Function} Unsubscribe function
   */
  subscribe({ timing, state, callback, guard = true }) {
    const id = Symbol();
    const subscription = { id, timing, state, callback, guard };

    if (timing === "immediate") {
      this.entryActions.push(subscription);
    } else {
      this.subscriptions.push(subscription);
    }

    return () => this.unsubscribe(id);
  }

  /**
   * Remove a subscription by its id.
   *
   * @param {Symbol} id
   */
  unsubscribe(id) {
    this.subscriptions = this.subscriptions.filter((s) => s.id !== id);
    this.entryActions = this.entryActions.filter((s) => s.id !== id);
  }

  /**
   * Remove all subscriptions from this machine.
   */
  cleanup() {
    this.subscriptions = [];
    this.entryActions = [];
  }

  /**
   * Initialize nested machines for a given state.
   *
   * @param {string} statePath
   */
  initializeNestedMachines(statePath) {
    const stateConfig = this.getStateConfig(statePath);
    if (stateConfig?.machines) {
      for (const machineDef of stateConfig.machines) {
        this.nestedMachines[machineDef.name] = machineDef.initial;
      }
    }
  }

  /**
   * Returns an array of all current state strings including nested machine states.
   *
   * @returns {string[]}
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
   * Get the configuration for a given state path.
   * Results are cached for performance.
   *
   * @param {string} statePath - Dot-notation state path
   * @returns {Object|null}
   */
  getStateConfig(statePath) {
    if (this.stateConfigCache.has(statePath)) {
      return this.stateConfigCache.get(statePath);
    }

    const parts = statePath.split(".");
    let config = this.definition.states[parts[0]];

    if (!config) {
      this.stateConfigCache.set(statePath, null);
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
            this.stateConfigCache.set(statePath, null);
            return null;
          }
        } else {
          this.stateConfigCache.set(statePath, null);
          return null;
        }
      } else {
        this.stateConfigCache.set(statePath, null);
        return null;
      }
    }

    this.stateConfigCache.set(statePath, config);
    return config;
  }

  /**
   * Get nested machine definition for a state.
   *
   * @param {string} stateName
   * @param {string} machineName
   * @returns {Object|null}
   */
  getNestedMachine(stateName, machineName) {
    const stateConfig = this.getStateConfig(stateName);
    if (!stateConfig || !stateConfig.machines) {
      return null;
    }
    return stateConfig.machines.find((m) => m.name === machineName);
  }

  /**
   * Get the current state of a nested machine.
   *
   * @param {string} machineName
   * @returns {string|null}
   */
  getNestedMachineState(machineName) {
    return this.nestedMachines[machineName] || null;
  }

  /**
   * Set the state of a nested machine.
   *
   * @param {string} machineName
   * @param {string} stateName
   */
  setNestedMachineState(machineName, stateName) {
    this.nestedMachines[machineName] = stateName;
  }

  /**
   * Get the parent state from a nested state path.
   *
   * @param {string} statePath
   * @returns {string|null}
   */
  getParentState(statePath) {
    const parts = statePath.split(".");
    return parts.length > 1 ? parts[0] : null;
  }

  /**
   * Send a message to the state machine.
   *
   * @param {string|Object} message
   * @param {Object} context
   * @returns {boolean}
   */
  send(message, context = {}) {
    const normalizedMessage =
      typeof message === "string" ? { type: message } : message;

    this.messageQueue.push({ message: normalizedMessage, context });

    if (!this.isProcessingQueue) {
      return this.processQueue();
    }

    return true;
  }

  /**
   * Process queued messages sequentially.
   *
   * @returns {boolean}
   * @private
   */
  processQueue() {
    if (this.messageQueue.length === 0) {
      this.isProcessingQueue = false;
      return false;
    }

    this.isProcessingQueue = true;
    let anyTransitioned = false;

    while (this.messageQueue.length > 0) {
      const { message, context } = this.messageQueue.shift();
      const transitioned = this.processMessage(message, context);
      if (transitioned) {
        anyTransitioned = true;
        this.notifySubscribers(message);
      }
      this.lastMessageTreated = message;
    }

    this.isProcessingQueue = false;
    return anyTransitioned;
  }

  /**
   * Process a single message.
   *
   * @param {Object} message
   * @param {Object} context
   * @returns {boolean}
   * @private
   */
  processMessage(message, context = {}) {
    const messageType = message.type;

    const currentStateConfig = this.getStateConfig(this.current);
    if (currentStateConfig?.machines) {
      for (const machineDef of currentStateConfig.machines) {
        const machineName = machineDef.name;
        const currentMachineState =
          this.getNestedMachineState(machineName) || machineDef.initial;
        const machineStateConfig = machineDef.states?.[currentMachineState];

        if (machineStateConfig?.on?.[messageType]) {
          const transitions = machineStateConfig.on[messageType];
          const transitionList = Array.isArray(transitions)
            ? transitions
            : [transitions];

          for (const transition of transitionList) {
            if (typeof transition === "string") {
              this.setNestedMachineState(machineName, transition);
              return true;
            }

            if (transition.guard) {
              if (!this.checkGuard(transition.guard, message, context)) {
                continue;
              }
            }

            if (transition.target) {
              this.setNestedMachineState(machineName, transition.target);
              return true;
            }
          }
        }
      }
    }

    let transitions = currentStateConfig?.on?.[messageType];

    if (!transitions) {
      const parentState = this.getParentState(this.current);
      if (parentState) {
        const parentConfig = this.getStateConfig(parentState);
        transitions = parentConfig?.on?.[messageType];
      }
    }

    if (!transitions) {
      return false;
    }

    const transitionList = Array.isArray(transitions)
      ? transitions
      : [transitions];

    for (const transition of transitionList) {
      if (typeof transition === "string") {
        this.transitionToState(transition);
        return true;
      }

      if (transition.guard) {
        if (!this.checkGuard(transition.guard, message, context)) {
          continue;
        }
      }

      if (transition.target) {
        this.transitionToState(transition.target);
        return true;
      }
    }

    return false;
  }

  /**
   * Transition to a new state, only recreating nestedMachines if needed.
   *
   * @param {string} targetState
   * @private
   */
  transitionToState(targetState) {
    this.current = targetState;
    const stateConfig = this.getStateConfig(targetState);
    if (stateConfig?.machines) {
      this.nestedMachines = new TrackedObject();
      this.initializeNestedMachines(targetState);
    }
  }

  /**
   * Check if a named guard condition is met.
   *
   * @param {string} guardName
   * @param {Object} message
   * @param {Object} context
   * @returns {boolean}
   */
  checkGuard(guardName, message, context) {
    const guardFn = this.guards[guardName];
    return guardFn ? guardFn(message, context) : true;
  }

  /**
   * Check if the machine is in a specific state.
   *
   * @param {string} state
   * @returns {boolean}
   */
  matches(state) {
    if (this.current === state) {
      return true;
    }

    const parts = state.split(".");
    if (parts.length >= 3) {
      const parentState = parts[0];
      const machineName = parts[1];
      const machineState = parts.slice(2).join(".");

      if (
        this.current === parentState ||
        this.current.startsWith(`${parentState}.`)
      ) {
        const currentMachineState = this.getNestedMachineState(machineName);
        if (currentMachineState === machineState) {
          return true;
        }
        if (
          currentMachineState?.startsWith(machineState) &&
          currentMachineState?.charAt(machineState.length) === "."
        ) {
          return true;
        }
      }
      return false;
    }

    return (
      this.current.startsWith(state) &&
      this.current.charAt(state.length) === "."
    );
  }

  /**
   * Update the machine context used by guards.
   *
   * @param {Object} newContext
   */
  updateContext(newContext) {
    this.context = { ...this.context, ...newContext };
  }

  /**
   * Check if a subscription's conditions are met.
   *
   * @param {Object} sub
   * @returns {boolean}
   * @private
   */
  matchesSubscription(sub) {
    const stateMatches = this.matches(sub.state);
    const guardPasses =
      typeof sub.guard === "function" ? sub.guard() : sub.guard;
    return stateMatches && guardPasses;
  }

  /**
   * Notify all subscribers after a state transition.
   *
   * @param {Object} message
   * @private
   */
  notifySubscribers(message) {
    for (const sub of this.entryActions) {
      if (this.matchesSubscription(sub)) {
        sub.callback(message);
      }
    }

    const beforePaint = this.subscriptions.filter(
      (s) => s.timing === "before-paint" && this.matchesSubscription(s)
    );
    for (const sub of beforePaint) {
      sub.callback(message);
    }

    const afterPaint = this.subscriptions.filter(
      (s) => s.timing === "after-paint" && this.matchesSubscription(s)
    );
    if (afterPaint.length > 0) {
      schedule("afterRender", () => {
        for (const sub of afterPaint) {
          if (this.matchesSubscription(sub)) {
            sub.callback(message);
          }
        }
      });
    }
  }
}

export default StateMachine;
