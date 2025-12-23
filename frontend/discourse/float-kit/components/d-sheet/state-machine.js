import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import { TrackedObject } from "@ember-compat/tracked-built-ins";

/**
 * Debug logging flag - enabled via console command debugSheetsStateMachine()
 */
let debugEnabled = false;

// Expose global function to enable debugging
if (typeof window !== "undefined") {
  window.debugSheetsStateMachine = () => {
    debugEnabled = true;
    // eslint-disable-next-line no-console
    console.log("[StateMachine] Debug logging enabled");
  };
}

/**
 * Log debug messages when debugging is enabled.
 *
 * @param {...any} args - Arguments to log
 */
function debugLog(...args) {
  if (debugEnabled) {
    // eslint-disable-next-line no-console
    console.log("[StateMachine]", ...args);
  }
}

/**
 * @typedef {Object} Subscription
 * @property {Symbol} id - Unique identifier for the subscription
 * @property {"immediate"|"before-paint"|"after-paint"} timing - When to invoke callback
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
 * @property {Object<string, function(Object, Object, Object): boolean>} [guards] - Guard functions for transitions (message, messageContext, machineContext) => boolean
 */

/**
 * Empty string message type used for automatic/immediate transitions.
 * When a state has an empty string handler, it triggers immediately upon entering that state.
 *
 * @constant {string}
 */
const AUTOMATIC_TRANSITION = "";

/**
 * Hierarchical state machine with support for nested machines and subscriptions.
 * Uses Glimmer tracking for automatic reactivity when state changes.
 *
 * @class StateMachine
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
  lastMessageTreated = null;

  /**
   * Queue of messages waiting to be processed.
   *
   * @type {QueuedMessage[]}
   */
  #messageQueue = [];

  /**
   * Whether the machine is currently processing the message queue.
   *
   * @type {boolean}
   */
  #isProcessingQueue = false;

  /**
   * Active subscriptions for state changes.
   *
   * @type {Subscription[]}
   */
  #subscriptions = [];

  /**
   * Actions to execute when entering a state.
   *
   * @type {Subscription[]}
   */
  #entryActions = [];

  /**
   * Actions to execute when exiting a state.
   *
   * @type {Subscription[]}
   */
  #exitActions = [];

  /**
   * Cache for state configurations to improve performance.
   *
   * @type {Map<string, Object|null>}
   */
  #stateConfigCache = new Map();

  /**
   * Guard functions for state transitions.
   *
   * @type {Object<string, function(Object, Object, Object): boolean>}
   */
  #guards = {};

  /**
   * Machine definitions for the current state.
   *
   * @type {Array|null}
   */
  #currentStateMachines = null;

  /**
   * Tracks which nested machines are silentOnly (don't trigger reactive updates).
   *
   * @type {Set<string>}
   */
  #silentMachines = new Set();

  /**
   * @param {Object} definition - State machine definition with states and transitions
   * @param {string} initialState - Initial state path (e.g., "closed.safe-to-unmount")
   * @param {StateMachineOptions} [options] - Optional configuration including guards
   */
  constructor(definition, initialState, options = {}) {
    this.definition = definition;
    this.current = initialState;
    this.#guards = options.guards || {};
    this.#initializeNestedMachines(this.current);
    this.#processAutomaticTransitions();
  }

  /**
   * Subscribe to state changes with timing control.
   *
   * @param {Object} options
   * @param {string} options.timing - "immediate" | "before-paint" | "after-paint"
   * @param {string|string[]} options.state - State pattern(s) to match
   * @param {Function} options.callback - Function to call when state matches
   * @param {Function|boolean} [options.guard] - Optional guard condition
   * @param {"enter"|"exit"} [options.type] - "enter" (default) or "exit" subscription
   * @returns {Function} Unsubscribe function
   */
  subscribe({ timing, state, callback, guard = true, type = "enter" }) {
    const id = Symbol();
    const subscription = { id, timing, state, callback, guard };

    if (type === "exit") {
      this.#exitActions.push(subscription);
    } else if (timing === "immediate") {
      this.#entryActions.push(subscription);
    } else {
      this.#subscriptions.push(subscription);
    }

    return () => this.#unsubscribe(id);
  }

  /**
   * Remove a subscription by its id.
   *
   * @param {Symbol} id
   */
  #unsubscribe(id) {
    this.#subscriptions = this.#subscriptions.filter((s) => s.id !== id);
    this.#entryActions = this.#entryActions.filter((s) => s.id !== id);
    this.#exitActions = this.#exitActions.filter((s) => s.id !== id);
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
   * Initialize nested machines for a given state.
   *
   * @param {string} statePath
   */
  #initializeNestedMachines(statePath) {
    const stateConfig = this.getStateConfig(statePath);
    this.#silentMachines.clear();

    if (stateConfig?.machines) {
      this.#currentStateMachines = stateConfig.machines;
      for (const machineDef of stateConfig.machines) {
        this.nestedMachines[machineDef.name] = machineDef.initial;
        if (machineDef.silentOnly) {
          this.#silentMachines.add(machineDef.name);
        }
      }
    } else {
      this.#currentStateMachines = null;
    }
  }

  /**
   * Check if a nested machine is silentOnly.
   *
   * @param {string} machineName
   * @returns {boolean}
   */
  #isSilentMachine(machineName) {
    return this.#silentMachines.has(machineName);
  }

  /**
   * Process automatic transitions (empty string message type).
   * Called after entering a new state to check for immediate transitions.
   */
  #processAutomaticTransitions() {
    const currentStateConfig = this.getStateConfig(this.current);

    // Check main state for automatic transitions
    if (currentStateConfig?.on?.[AUTOMATIC_TRANSITION]) {
      const previousState = this.current;
      const previousNestedStates = { ...this.nestedMachines };

      const transitioned = this.#tryTransitions(
        currentStateConfig.on[AUTOMATIC_TRANSITION],
        { type: AUTOMATIC_TRANSITION },
        {},
        (target) => this.#transitionToState(target)
      );

      if (transitioned) {
        const { entered, exited } = this.#calculateStateChanges(
          previousState,
          previousNestedStates
        );
        this.#notifySubscribers(
          { type: AUTOMATIC_TRANSITION },
          entered,
          exited
        );
        // Recursively check for more automatic transitions
        this.#processAutomaticTransitions();
        return;
      }
    }

    // Check nested machines for automatic transitions
    if (currentStateConfig?.machines) {
      for (const machineDef of currentStateConfig.machines) {
        const machineName = machineDef.name;
        const currentMachineState =
          this.getNestedMachineState(machineName) || machineDef.initial;
        const machineStateConfig = machineDef.states?.[currentMachineState];

        if (machineStateConfig?.on?.[AUTOMATIC_TRANSITION]) {
          const previousState = this.current;
          const previousNestedStates = { ...this.nestedMachines };

          const transitioned = this.#tryTransitions(
            machineStateConfig.on[AUTOMATIC_TRANSITION],
            { type: AUTOMATIC_TRANSITION },
            {},
            (target) => this.#setNestedMachineState(machineName, target)
          );

          if (transitioned) {
            const { entered, exited } = this.#calculateStateChanges(
              previousState,
              previousNestedStates
            );
            // Only notify if not a silent machine
            if (!this.#isSilentMachine(machineName)) {
              this.#notifySubscribers(
                { type: AUTOMATIC_TRANSITION },
                entered,
                exited
              );
            }
            // Recursively check for more automatic transitions
            this.#processAutomaticTransitions();
            return;
          }
        }
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
   *
   * @param {string} statePath - Dot-notation state path
   * @returns {Object|null}
   */
  getStateConfig(statePath) {
    if (this.#stateConfigCache.has(statePath)) {
      return this.#stateConfigCache.get(statePath);
    }

    const parts = statePath.split(".");
    let config = this.definition.states[parts[0]];

    if (!config) {
      this.#stateConfigCache.set(statePath, null);
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
            this.#stateConfigCache.set(statePath, null);
            return null;
          }
        } else {
          this.#stateConfigCache.set(statePath, null);
          return null;
        }
      } else {
        this.#stateConfigCache.set(statePath, null);
        return null;
      }
    }

    this.#stateConfigCache.set(statePath, config);
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
  #setNestedMachineState(machineName, stateName) {
    this.nestedMachines[machineName] = stateName;
  }

  /**
   * Get the parent state from a nested state path.
   *
   * @param {string} statePath
   * @returns {string|null}
   */
  #getParentState(statePath) {
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

    debugLog(
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
   * Process queued messages sequentially.
   *
   * @returns {boolean}
   */
  #processQueue() {
    if (this.#messageQueue.length === 0) {
      this.#isProcessingQueue = false;
      return false;
    }

    this.#isProcessingQueue = true;
    let anyTransitioned = false;

    while (this.#messageQueue.length > 0) {
      const { message, context } = this.#messageQueue.shift();
      const { transitioned, enteredStates, exitedStates, silent } =
        this.#processMessage(message, context);

      // Set lastMessageTreated BEFORE notifying so guards can access the current message
      this.lastMessageTreated = message;

      if (transitioned) {
        anyTransitioned = true;
        // Only notify subscribers if not a silent transition
        if (!silent) {
          this.#notifySubscribers(message, enteredStates, exitedStates);
        }
      }
    }

    this.#isProcessingQueue = false;
    return anyTransitioned;
  }

  /**
   * Try to execute transitions from a transition list.
   *
   * @param {Array|Object|string} transitions - Transition definition(s)
   * @param {Object} message - The message being processed
   * @param {Object} context - Context for guards
   * @param {Function} onSuccess - Callback when a transition succeeds, receives target state
   * @returns {boolean} Whether a transition was executed
   */
  #tryTransitions(transitions, message, context, onSuccess) {
    const transitionList = Array.isArray(transitions)
      ? transitions
      : [transitions];

    for (const transition of transitionList) {
      if (typeof transition === "string") {
        debugLog(`tryTransitions: direct target "${transition}"`);
        onSuccess(transition);
        return true;
      }

      if (transition.guard) {
        const guardPassed = this.#checkGuard(transition.guard, message, context);
        debugLog(
          `tryTransitions: guard "${transition.guard}" -> ${guardPassed}`
        );
        if (!guardPassed) {
          continue;
        }
      }

      if (transition.target) {
        debugLog(`tryTransitions: target "${transition.target}"`);
        onSuccess(transition.target);
        return true;
      }
    }

    debugLog(`tryTransitions: no valid transition found`);
    return false;
  }

  /**
   * Check if a target state is a cross-level transition (targets a different parent state).
   *
   * @param {string} target - Target state path
   * @param {string} machineName - Current nested machine name
   * @param {Object} machineDef - Current nested machine definition
   * @returns {boolean}
   */
  #isCrossLevelTransition(target, machineName, machineDef) {
    // If target contains a dot, it might be a full path like "out" or "front.status:idle"
    // Check if target is a valid state within the nested machine
    if (machineDef.states?.[target]) {
      return false; // Target exists in nested machine, not cross-level
    }
    // Target is not in the nested machine, so it's a cross-level transition
    return true;
  }

  /**
   * Process nested machine transitions silently.
   * This is used after main state transitions to also update silentOnly machines.
   *
   * @param {Object} message
   * @param {Object} context
   */
  #processNestedMachinesSilently(message, context) {
    const messageType = message.type;
    const currentStateConfig = this.getStateConfig(this.current);

    debugLog(`processNestedMachinesSilently: message=${messageType}`);

    if (!currentStateConfig?.machines) {
      debugLog(`processNestedMachinesSilently: no machines to process`);
      return;
    }

    for (const machineDef of currentStateConfig.machines) {
      // Only process silentOnly machines here
      if (!machineDef.silentOnly) {
        continue;
      }

      const machineName = machineDef.name;
      const currentMachineState =
        this.getNestedMachineState(machineName) || machineDef.initial;
      const machineStateConfig = machineDef.states?.[currentMachineState];

      debugLog(
        `processNestedMachinesSilently: checking silentOnly machine "${machineName}", currentState="${currentMachineState}"`
      );

      if (machineStateConfig?.on?.[messageType]) {
        debugLog(
          `processNestedMachinesSilently: "${machineName}" handles "${messageType}"`
        );
        this.#tryTransitions(
          machineStateConfig.on[messageType],
          message,
          context,
          (target) => {
            debugLog(
              `processNestedMachinesSilently: "${machineName}" transitioning to "${target}"`
            );
            if (!this.#isCrossLevelTransition(target, machineName, machineDef)) {
              this.#setNestedMachineState(machineName, target);
            }
          }
        );
      }
    }
  }

  /**
   * Process a single message.
   *
   * @param {Object} message
   * @param {Object} context
   * @returns {{transitioned: boolean, enteredStates: string[], exitedStates: string[], silent: boolean}}
   */
  #processMessage(message, context = {}) {
    const messageType = message.type;

    const previousState = this.current;
    const previousNestedStates = { ...this.nestedMachines };

    debugLog(
      `processMessage: type=${messageType}, previousState=${previousState}, nestedStates:`,
      previousNestedStates
    );

    const currentStateConfig = this.getStateConfig(this.current);

    // First, check main state for transitions - main state takes priority
    let mainStateTransitioned = false;
    let transitions = currentStateConfig?.on?.[messageType];
    debugLog(
      `processMessage: checking main state transitions, found:`,
      transitions ? "yes" : "no"
    );

    if (!transitions) {
      const parentState = this.#getParentState(this.current);
      if (parentState) {
        const parentConfig = this.getStateConfig(parentState);
        transitions = parentConfig?.on?.[messageType];
      }
    }

    if (transitions) {
      mainStateTransitioned = this.#tryTransitions(
        transitions,
        message,
        context,
        (target) => this.#transitionToState(target)
      );

      if (mainStateTransitioned) {
        // Process automatic transitions after main state transition
        this.#processAutomaticTransitions();

        // Also process silentOnly nested machines so they can track messages
        // (e.g., evaluateCloseMessage, evaluateStepMessage)
        this.#processNestedMachinesSilently(message, context);

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
    }

    // If main state didn't handle the message, check nested machines
    if (currentStateConfig?.machines) {
      for (const machineDef of currentStateConfig.machines) {
        const machineName = machineDef.name;
        const currentMachineState =
          this.getNestedMachineState(machineName) || machineDef.initial;
        const machineStateConfig = machineDef.states?.[currentMachineState];

        if (machineStateConfig?.on?.[messageType]) {
          const transitioned = this.#tryTransitions(
            machineStateConfig.on[messageType],
            message,
            context,
            (target) => {
              // Check if this is a cross-level transition to a parent state
              if (this.#isCrossLevelTransition(target, machineName, machineDef)) {
                // Transition the main state machine
                this.#transitionToState(target);
              } else {
                // Stay within nested machine
                this.#setNestedMachineState(machineName, target);
              }
            }
          );
          if (transitioned) {
            // Process automatic transitions in the nested machine's new state
            this.#processNestedMachineAutomaticTransitions(machineName);

            const { entered, exited } = this.#calculateStateChanges(
              previousState,
              previousNestedStates
            );
            const isSilent = this.#isSilentMachine(machineName);
            return {
              transitioned: true,
              enteredStates: entered,
              exitedStates: exited,
              silent: isSilent,
            };
          }
        }
      }
    }

    return {
      transitioned: false,
      enteredStates: [],
      exitedStates: [],
      silent: false,
    };
  }

  /**
   * Process automatic transitions for a specific nested machine.
   *
   * @param {string} machineName
   */
  #processNestedMachineAutomaticTransitions(machineName) {
    const currentStateConfig = this.getStateConfig(this.current);
    if (!currentStateConfig?.machines) {
      return;
    }

    const machineDef = currentStateConfig.machines.find(
      (m) => m.name === machineName
    );
    if (!machineDef) {
      return;
    }

    const currentMachineState =
      this.getNestedMachineState(machineName) || machineDef.initial;
    const machineStateConfig = machineDef.states?.[currentMachineState];

    if (machineStateConfig?.on?.[AUTOMATIC_TRANSITION]) {
      const transitioned = this.#tryTransitions(
        machineStateConfig.on[AUTOMATIC_TRANSITION],
        { type: AUTOMATIC_TRANSITION },
        {},
        (target) => this.#setNestedMachineState(machineName, target)
      );

      if (transitioned) {
        // Recursively check for more automatic transitions
        this.#processNestedMachineAutomaticTransitions(machineName);
      }
    }
  }

  /**
   * Calculate which states were entered and exited during a transition.
   *
   * @param {string} previousState - State before transition
   * @param {Object} previousNestedStates - Nested machine states before transition
   * @returns {{entered: string[], exited: string[]}} Arrays of state paths that were entered/exited
   */
  #calculateStateChanges(previousState, previousNestedStates) {
    const entered = [];
    const exited = [];

    const parentState = this.current.split(".")[0];
    const prevParentState = previousState.split(".")[0];

    debugLog(
      `calculateStateChanges: previousState=${previousState}, currentState=${this.current}`
    );

    // Always add current state to entered when a transition occurs
    // This handles both state changes AND self-transitions (e.g., STEP staying in "open")
    entered.push(this.current);

    if (this.current !== previousState) {
      exited.push(previousState);
    }

    for (const [machineName, machineState] of Object.entries(
      this.nestedMachines
    )) {
      const prevMachineState = previousNestedStates[machineName];
      if (prevMachineState !== machineState) {
        // Use ":" as separator for nested machine states (e.g., "front.status:idle")
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
          // Use ":" as separator for nested machine states
          exited.push(`${prevParentState}.${machineName}:${machineState}`);
        }
      }
    }

    debugLog(`calculateStateChanges: entered=`, entered, `exited=`, exited);
    return { entered, exited };
  }

  /**
   * Transition to a new state, only recreating nestedMachines if machine definitions change.
   * Handles two types of state paths:
   * - Nested STATE paths: "closed.pending" - hierarchical states, full path stored in this.current
   * - Nested MACHINE paths: "front.status:idle" - parent state with nested machine state
   *
   * @param {string} targetState - Can be a simple state, nested state, or nested machine path
   */
  #transitionToState(targetState) {
    const previousState = this.current;
    debugLog(`transitionToState: ${previousState} -> ${targetState}`);

    // Check if this is a nested MACHINE path (contains ":")
    // Format: "parentState.machineName:machineState"
    const colonIndex = targetState.indexOf(":");

    if (colonIndex !== -1) {
      // Nested MACHINE path like "front.status:idle"
      const dotIndex = targetState.indexOf(".");
      const mainState = targetState.substring(0, dotIndex);
      const rest = targetState.substring(dotIndex + 1); // "status:idle"

      debugLog(
        `transitionToState: nested MACHINE path, mainState=${mainState}`
      );

      this.current = mainState;
      const stateConfig = this.getStateConfig(mainState);
      const newMachines = stateConfig?.machines || null;

      if (this.#machinesAreDifferent(this.#currentStateMachines, newMachines)) {
        debugLog(`transitionToState: reinitializing nested machines`);
        this.nestedMachines = new TrackedObject();
        this.#initializeNestedMachines(mainState);
      }

      // Parse nested machine state (e.g., "status:idle")
      const machineColonIndex = rest.indexOf(":");
      const machineName = rest.substring(0, machineColonIndex); // "status"
      const machineState = rest.substring(machineColonIndex + 1); // "idle"
      debugLog(
        `transitionToState: setting nested machine ${machineName}=${machineState}`
      );
      this.#setNestedMachineState(machineName, machineState);
      return;
    }

    // No colon - either simple state or nested STATE path
    // For nested STATE paths like "closed.pending", store the full path
    this.current = targetState;

    // Get config for the full path to check for machines
    const stateConfig = this.getStateConfig(targetState);
    const newMachines = stateConfig?.machines || null;

    if (this.#machinesAreDifferent(this.#currentStateMachines, newMachines)) {
      this.nestedMachines = new TrackedObject();
      this.#initializeNestedMachines(targetState);
    }
  }

  /**
   * Check if two machine definition arrays are different.
   *
   * @param {Array|null} oldMachines
   * @param {Array|null} newMachines
   * @returns {boolean}
   */
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

  /**
   * Check if a named guard condition is met.
   *
   * @param {string} guardName
   * @param {Object} message
   * @param {Object} messageContext
   * @returns {boolean}
   */
  #checkGuard(guardName, message, messageContext) {
    const guardFn = this.#guards[guardName];
    return guardFn ? guardFn(message, messageContext, this.context) : true;
  }

  /**
   * Check if the machine is in a specific nested machine state.
   * Handles format "parentState.machineName:machineState"
   *
   * @param {string} state - State pattern with format "parentState.machineName:machineState"
   * @returns {boolean}
   */
  #matchesNestedMachineState(state) {
    // Format: "front.status:idle"
    const dotIndex = state.indexOf(".");
    const colonIndex = state.indexOf(":");

    if (dotIndex === -1 || colonIndex === -1) {
      return false;
    }

    const parentState = state.substring(0, dotIndex); // "front"
    const machineName = state.substring(dotIndex + 1, colonIndex); // "status"
    const machineState = state.substring(colonIndex + 1); // "idle"

    // Check if we're in the parent state
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

    // Check for hierarchical match (e.g., "idle" matches "idle.substatus")
    return (
      currentMachineState?.startsWith(machineState) &&
      currentMachineState?.charAt(machineState.length) === "."
    );
  }

  /**
   * Check if the machine is in a specific state.
   * Handles multiple formats:
   * - Simple state: "open"
   * - Nested state: "closed.pending"
   * - Nested machine state: "front.status:idle"
   *
   * @param {string} state
   * @returns {boolean}
   */
  matches(state) {
    // Exact match
    if (this.current === state) {
      return true;
    }

    // Check if this is a nested machine state format (contains ":")
    if (state.includes(":")) {
      return this.#matchesNestedMachineState(state);
    }

    // Hierarchical state match (e.g., "closed" matches "closed.pending")
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
   */
  #matchesSubscription(sub) {
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

  /**
   * Check if a subscription's state was entered during this transition.
   *
   * @param {Object} sub - Subscription object
   * @param {string[]} enteredStates - States that were entered in this transition
   * @returns {boolean}
   */
  #wasStateEntered(sub, enteredStates) {
    const subStates = Array.isArray(sub.state) ? sub.state : [sub.state];

    for (const subState of subStates) {
      const found = enteredStates.includes(subState);
      debugLog(
        `wasStateEntered: checking "${subState}" in`,
        enteredStates,
        `-> ${found}`
      );
      if (found) {
        return true;
      }
    }
    return false;
  }

  /**
   * Check if a subscription's state was exited during this transition.
   *
   * @param {Object} sub - Subscription object
   * @param {string[]} exitedStates - States that were exited in this transition
   * @returns {boolean}
   */
  #wasStateExited(sub, exitedStates) {
    const subStates = Array.isArray(sub.state) ? sub.state : [sub.state];

    for (const subState of subStates) {
      if (exitedStates.includes(subState)) {
        return true;
      }
    }
    return false;
  }

  /**
   * Notify all subscribers after a state transition.
   *
   * @param {Object} message
   * @param {string[]} enteredStates - States that were entered in this transition
   * @param {string[]} exitedStates - States that were exited in this transition
   */
  #notifySubscribers(message, enteredStates, exitedStates) {
    debugLog(
      `notifySubscribers: message=${message.type}, enteredStates=`,
      enteredStates,
      `exitedStates=`,
      exitedStates
    );
    debugLog(
      `notifySubscribers: ${this.#exitActions.length} exit actions, ${this.#entryActions.length} entry actions, ${this.#subscriptions.length} subscriptions`
    );

    for (const sub of this.#exitActions) {
      const wasExited = this.#wasStateExited(sub, exitedStates);
      const guardPasses =
        typeof sub.guard === "function" ? sub.guard() : sub.guard;

      debugLog(
        `notifySubscribers: exit action for state="${sub.state}", wasExited=${wasExited}, guardPasses=${guardPasses}`
      );
      if (wasExited && guardPasses) {
        debugLog(`notifySubscribers: FIRING exit callback for "${sub.state}"`);
        sub.callback(message);
      }
    }

    for (const sub of this.#entryActions) {
      const wasEntered = this.#wasStateEntered(sub, enteredStates);
      const guardPasses =
        typeof sub.guard === "function" ? sub.guard() : sub.guard;

      debugLog(
        `notifySubscribers: entry action for state="${sub.state}", wasEntered=${wasEntered}, guardPasses=${guardPasses}`
      );
      if (wasEntered && guardPasses) {
        debugLog(`notifySubscribers: FIRING entry callback for "${sub.state}"`);
        sub.callback(message);
      }
    }

    let afterPaintSubs = null;

    for (const sub of this.#subscriptions) {
      if (!this.#matchesSubscription(sub)) {
        continue;
      }

      if (sub.timing === "before-paint") {
        sub.callback(message);
      } else if (sub.timing === "after-paint") {
        if (!afterPaintSubs) {
          afterPaintSubs = [];
        }
        afterPaintSubs.push(sub);
      }
    }

    if (afterPaintSubs) {
      schedule("afterRender", () => {
        for (const sub of afterPaintSubs) {
          if (this.#matchesSubscription(sub)) {
            sub.callback(message);
          }
        }
      });
    }
  }
}

export default StateMachine;
