import { tracked } from "@glimmer/tracking";
import StateMachine from "./state-machine";

/**
 * @typedef {Object} MachineDefinition
 * @property {string} name - Unique name identifying the machine within the group
 * @property {string} initial - Initial state path for the machine
 * @property {Object<string, Object>} states - Map of state names to configurations
 * @property {boolean} [silentOnly] - If true, state changes don't trigger reactive updates
 */

/**
 * @typedef {Object} StateMachineGroupOptions
 * @property {Object<string, function(string[], Object): boolean>} [guards] - Guard functions for transitions
 */

/**
 * Manages an array of named state machines, enabling cross-machine
 * transitions via prefix syntax (e.g., "machineName:state.nested:value").
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
   * @type {Object<string, function(string[], Object): boolean>}
   */
  #guards;

  /**
   * Create a new StateMachineGroup.
   *
   * @param {MachineDefinition[]} machineDefinitions - Array of machine definitions to instantiate
   * @param {StateMachineGroupOptions} [options] - Configuration options for the group
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
   * @returns {void}
   */
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
   * @returns {void}
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
}
