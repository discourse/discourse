import { tracked } from "@glimmer/tracking";
import StateMachine from "./state-machine";

/**
 * Manages an array of named state machines, enabling cross-machine
 * transitions via prefix syntax (e.g., "machineName:state.nested:value").
 *
 * This matches Silk's tw() function architecture.
 *
 * @class StateMachineGroup
 */
export default class StateMachineGroup {
  /**
   * Tracked version counter for reactivity.
   * @type {number}
   */
  @tracked version = 0;

  /**
   * Map of machine names to StateMachine instances.
   * @type {Map<string, StateMachine>}
   */
  #machines = new Map();

  /**
   * Guard functions shared across all machines.
   * @type {Object}
   */
  #guards;

  /**
   * Create a new StateMachineGroup.
   *
   * @param {Array<{name: string, initial: string, states: Object}>} machineDefinitions
   * @param {Object} options
   * @param {Object} [options.guards] - Guard functions for transitions
   */
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

  /**
   * Check if a machine exists in this group.
   *
   * @param {string} name - Machine name
   * @returns {boolean}
   */
  hasMachine(name) {
    return this.#machines.has(name);
  }

  /**
   * Get a machine by name.
   *
   * @param {string} name - Machine name
   * @returns {StateMachine|undefined}
   */
  getMachine(name) {
    return this.#machines.get(name);
  }

  /**
   * Send a message to all machines in the group.
   * Each machine independently processes the message.
   *
   * @param {string|{type: string}} message - Message to send
   * @param {Object} [context] - Context for guards
   */
  send(message, context = {}) {
    for (const machine of this.#machines.values()) {
      machine.send(message, context);
    }
    this.version++;
  }

  /**
   * Send a message to a specific machine by name.
   *
   * @param {string} machineName - Target machine name
   * @param {string|{type: string}} message - Message to send
   * @param {Object} [context] - Context for guards
   */
  sendTo(machineName, message, context = {}) {
    const machine = this.#machines.get(machineName);
    if (machine) {
      machine.send(message, context);
      this.version++;
    }
  }

  /**
   * Check if any machine matches the given pattern.
   * Pattern can be:
   * - "machineName:state" - specific machine state
   * - "machineName:state.nested:value" - nested machine state
   *
   * @param {string} pattern - State pattern to match
   * @returns {boolean}
   */
  matches(pattern) {
    // Trigger reactivity
    void this.version;

    const colonIndex = pattern.indexOf(":");
    if (colonIndex === -1) {
      // No prefix - check all machines for this state
      for (const machine of this.#machines.values()) {
        if (machine.matches(pattern)) {
          return true;
        }
      }
      return false;
    }

    const machineName = pattern.substring(0, colonIndex);
    const statePattern = pattern.substring(colonIndex + 1);

    const machine = this.#machines.get(machineName);
    return machine ? machine.matches(statePattern) : false;
  }

  /**
   * Get all current states as an array of prefixed strings.
   *
   * @returns {string[]}
   */
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

  /**
   * Transition to a specific state, handling cross-machine transitions.
   * Called by child machines when they encounter a prefixed target.
   *
   * @param {string} target - Full target path (e.g., "position:front.status:idle")
   */
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

  /**
   * Subscribe to state changes across all machines or a specific machine.
   *
   * @param {Object} options - Subscription options
   * @param {string} [options.machine] - Target specific machine by name
   * @returns {Symbol} Subscription ID
   */
  subscribe(options) {
    const { machine: machineName, ...subOptions } = options;

    if (machineName) {
      const machine = this.#machines.get(machineName);
      return machine?.subscribe(subOptions);
    }

    // Subscribe to all machines
    const ids = [];
    for (const machine of this.#machines.values()) {
      ids.push(machine.subscribe(subOptions));
    }
    return ids[0]; // Return first ID for compatibility
  }

  /**
   * Unsubscribe from state changes.
   *
   * @param {Symbol} id - Subscription ID
   */
  unsubscribe(id) {
    for (const machine of this.#machines.values()) {
      machine.unsubscribe(id);
    }
  }
}
