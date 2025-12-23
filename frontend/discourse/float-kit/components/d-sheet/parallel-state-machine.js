import { tracked } from "@glimmer/tracking";
import StateMachine from "./state-machine";

/**
 * @typedef {Object} ParallelMachineDefinition
 * @property {string} name - Unique name for this machine
 * @property {string} initial - Initial state
 * @property {Object<string, Object>} states - Map of state names to configurations
 * @property {boolean} [silentOnly] - If true, state changes don't trigger reactive updates
 */

/**
 * Parallel state machine that wraps multiple independent machines.
 * Messages are broadcast to all machines that can handle them.
 * State is represented as an array of strings (one per machine).
 *
 * ["staging:none", "longRunning:false", "openness:closed.status:safe-to-unmount", ...]
 *
 * @class ParallelStateMachine
 */
class ParallelStateMachine {
  /**
   * Map of machine names to StateMachine instances.
   *
   * @type {Map<string, StateMachine>}
   */
  #machines = new Map();

  /**
   * Ordered list of machine names for consistent toStrings() output.
   *
   * @type {string[]}
   */
  #machineOrder = [];

  /**
   * Set of machine names that are silentOnly.
   *
   * @type {Set<string>}
   */
  #silentMachines = new Set();

  /**
   * Guard functions shared across all machines.
   *
   * @type {Object<string, function(Object, Object, Object): boolean>}
   */
  #guards = {};

  /**
   * Shared context across all machines.
   *
   * @type {Object}
   */
  context = {};

  /**
   * The last message that was processed.
   *
   * @type {{type: string}|null}
   */
  @tracked lastProcessedMessage = null;

  /**
   * Version counter for reactivity - incremented on state changes.
   *
   * @type {number}
   */
  @tracked _version = 0;

  /**
   * Create a parallel state machine from an array of machine definitions.
   *
   * @param {ParallelMachineDefinition[]} definitions - Array of machine definitions
   * @param {Object} [options] - Optional configuration
   * @param {Object} [options.guards] - Guard functions for transitions
   */
  constructor(definitions, options = {}) {
    this.#guards = options.guards || {};

    for (const def of definitions) {
      const machine = new StateMachine(
        { initial: def.initial, states: def.states },
        def.initial,
        { guards: this.#guards }
      );
      this.#machines.set(def.name, machine);
      this.#machineOrder.push(def.name);

      if (def.silentOnly) {
        this.#silentMachines.add(def.name);
      }
    }
  }

  /**
   * Get a specific machine by name.
   *
   * @param {string} name - Machine name
   * @returns {StateMachine|null}
   */
  getMachine(name) {
    return this.#machines.get(name) || null;
  }

  /**
   * Get the current state of a specific machine.
   *
   * @param {string} machineName - Machine name
   * @returns {string|null}
   */
  getState(machineName) {
    const machine = this.#machines.get(machineName);
    return machine ? machine.current : null;
  }

  /**
   * Returns an array of all current state strings from all machines.
   * Format: "machineName:state" or "machineName:state.nestedMachine:nestedState"
   *
   * @returns {string[]}
   */
  toStrings() {
    // Touch version for reactivity
    // eslint-disable-next-line no-unused-expressions
    this._version;

    const strings = [];
    for (const name of this.#machineOrder) {
      const machine = this.#machines.get(name);
      if (machine) {
        // Get main state
        strings.push(`${name}:${machine.current}`);

        // Get nested machine states
        const nestedStrings = machine.toStrings();
        for (let i = 1; i < nestedStrings.length; i++) {
          // Skip the first one (main state), add nested with proper prefix
          const nestedParts = nestedStrings[i].split(".");
          if (nestedParts.length >= 2) {
            strings.push(`${name}:${nestedStrings[i]}`);
          }
        }
      }
    }
    return strings;
  }

  /**
   * Check if any machine matches the given state pattern.
   * Supports patterns like:
   * - "machineName:state" - exact match
   * - "machineName:parent.child" - hierarchical match
   * - Array of patterns - matches if any pattern matches
   *
   * @param {string|string[]} pattern - State pattern(s) to match
   * @returns {boolean}
   */
  matches(pattern) {
    // Touch version for reactivity
    // eslint-disable-next-line no-unused-expressions
    this._version;

    const states = this.toStrings();

    if (Array.isArray(pattern)) {
      return (
        pattern.some((p) => states.includes(p)) ||
        states.some((s) =>
          pattern.some((p) => s.startsWith(p) && s.charAt(p.length) === ".")
        )
      );
    }

    return (
      states.includes(pattern) ||
      states.some(
        (s) => s.startsWith(pattern) && s.charAt(pattern.length) === "."
      )
    );
  }

  /**
   * Send a message to all machines that can handle it.
   * Messages are broadcast to all machines, not just one.
   *
   * @param {string|Object} message - Message to send
   * @param {Object} [context] - Context for guards
   * @returns {boolean} Whether any machine transitioned
   */
  send(message, context = {}) {
    const normalizedMessage =
      typeof message === "string" ? { type: message } : message;

    let anyTransitioned = false;
    let anyReactive = false;

    // Broadcast to all machines
    for (const [name, machine] of this.#machines) {
      // Update machine context with shared context
      machine.updateContext({ ...this.context, ...context });

      const transitioned = machine.send(normalizedMessage, context);
      if (transitioned) {
        anyTransitioned = true;
        if (!this.#silentMachines.has(name)) {
          anyReactive = true;
        }
      }
    }

    this.lastProcessedMessage = normalizedMessage;

    // Only increment version for reactive changes
    if (anyReactive) {
      this._version++;
    }

    return anyTransitioned;
  }

  /**
   * Send a message to a specific machine only.
   *
   * @param {string} machineName - Target machine name
   * @param {string|Object} message - Message to send
   * @param {Object} [context] - Context for guards
   * @returns {boolean} Whether the machine transitioned
   */
  sendTo(machineName, message, context = {}) {
    const machine = this.#machines.get(machineName);
    if (!machine) {
      return false;
    }

    const normalizedMessage =
      typeof message === "string" ? { type: message } : message;

    machine.updateContext({ ...this.context, ...context });
    const transitioned = machine.send(normalizedMessage, context);

    if (transitioned && !this.#silentMachines.has(machineName)) {
      this._version++;
    }

    this.lastProcessedMessage = normalizedMessage;
    return transitioned;
  }

  /**
   * Subscribe to state changes on a specific machine.
   *
   * @param {string} machineName - Machine to subscribe to
   * @param {Object} options - Subscription options
   * @returns {Function} Unsubscribe function
   */
  subscribe(machineName, options) {
    const machine = this.#machines.get(machineName);
    if (!machine) {
      return () => {};
    }
    return machine.subscribe(options);
  }

  /**
   * Subscribe to state changes across all machines.
   * The state pattern should include the machine name prefix.
   *
   * @param {Object} options - Subscription options
   * @param {string|string[]} options.state - State pattern(s) with machine prefix
   * @param {Function} options.callback - Callback function
   * @param {string} [options.timing] - Timing for callback
   * @param {Function|boolean} [options.guard] - Guard condition
   * @param {"enter"|"exit"} [options.type] - Subscription type
   * @returns {Function} Unsubscribe function
   */
  subscribeAll(options) {
    const unsubscribers = [];

    const statePatterns = Array.isArray(options.state)
      ? options.state
      : [options.state];

    for (const pattern of statePatterns) {
      // Parse machine name from pattern (e.g., "openness:open" -> "openness")
      const colonIndex = pattern.indexOf(":");
      if (colonIndex === -1) {
        continue;
      }

      const machineName = pattern.substring(0, colonIndex);
      const statePattern = pattern.substring(colonIndex + 1);

      const machine = this.#machines.get(machineName);
      if (!machine) {
        continue;
      }

      const unsub = machine.subscribe({
        ...options,
        state: statePattern,
      });
      unsubscribers.push(unsub);
    }

    return () => {
      for (const unsub of unsubscribers) {
        unsub();
      }
    };
  }

  /**
   * Update the shared context used by guards.
   *
   * @param {Object} newContext
   */
  updateContext(newContext) {
    this.context = { ...this.context, ...newContext };

    // Update context on all machines
    for (const machine of this.#machines.values()) {
      machine.updateContext(newContext);
    }
  }

  /**
   * Clean up all machines and their subscriptions.
   */
  cleanup() {
    for (const machine of this.#machines.values()) {
      machine.cleanup();
    }
  }

  /**
   * Get the current state of all machines as a plain object.
   * Useful for debugging.
   *
   * @returns {Object<string, string>}
   */
  getSnapshot() {
    const snapshot = {};
    for (const [name, machine] of this.#machines) {
      snapshot[name] = machine.current;
    }
    return snapshot;
  }
}

export default ParallelStateMachine;

