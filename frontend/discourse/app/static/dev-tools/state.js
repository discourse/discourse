import { tracked } from "@glimmer/tracking";
import { trackedMap } from "@ember/reactive/collections";

/**
 * Singleton class that manages the state of developer tools.
 * State is persisted to sessionStorage so it survives page refreshes
 * but not browser restarts. Each property is tracked for reactivity.
 *
 * @class DevToolsState
 */
class DevToolsState {
  static #SESSION_STORAGE_KEY = "discourse__dev_tools_state";

  /**
   * State belonging to registered tools, keyed by tool identifier.
   *
   * The singleton is sealed with `Object.preventExtensions` once created, so a
   * tool cannot store state by assigning a new property to it. This map gives
   * them somewhere to write instead, reached through `getFlag` and `setFlag`
   * rather than being exposed directly.
   *
   * A map rather than an object because tool identifiers come from callers: an
   * object would treat `__proto__` as a reserved name, silently discarding that
   * tool's state instead of storing it.
   */
  #flags = trackedMap();

  // Private backing fields for tracked properties.
  // These are @tracked so that Glimmer re-renders when values change.
  @tracked _pluginOutletDebug;
  @tracked _blockDebug;
  @tracked _blockVisualOverlay;
  @tracked _blockGhostBlocks;
  @tracked _blockOutletBoundaries;

  /**
   * Initializes the state by loading persisted values from sessionStorage.
   * Falls back to false for any missing values.
   */
  constructor() {
    const persisted = this.#loadPersistedState();
    this._pluginOutletDebug = persisted.pluginOutletDebug ?? false;
    this._blockDebug = persisted.blockDebug ?? false;
    this._blockVisualOverlay = persisted.blockVisualOverlay ?? false;
    this._blockGhostBlocks = persisted.blockGhostBlocks ?? false;
    this._blockOutletBoundaries = persisted.blockOutletBoundaries ?? false;

    for (const [toolId, values] of Object.entries(persisted.flags ?? {})) {
      this.#flags.set(toolId, values);
    }
  }

  /**
   * Reads a value stored by a registered tool.
   *
   * @param {string} toolId - The identifier the tool was registered under.
   * @param {string} key - The name of the value within that tool's state.
   * @returns {any} The stored value, or undefined when it has never been set.
   */
  getFlag(toolId, key) {
    return this.#flags.get(toolId)?.[key];
  }

  /**
   * Stores a value for a registered tool and persists it.
   *
   * @param {string} toolId - The identifier the tool was registered under.
   * @param {string} key - The name of the value within that tool's state.
   * @param {any} value - The value to store. Must survive `JSON.stringify`.
   */
  setFlag(toolId, key, value) {
    // Replace rather than mutate, so that reading a tool's whole state object
    // is enough to be notified of a change to any single value in it.
    this.#flags.set(toolId, { ...this.#flags.get(toolId), [key]: value });
    this.#persistState();
  }

  /**
   * Load persisted state from sessionStorage.
   *
   * @returns {Object} Parsed state object or empty object if not found
   */
  #loadPersistedState() {
    try {
      const stored = window.sessionStorage?.getItem(
        DevToolsState.#SESSION_STORAGE_KEY
      );
      return stored ? JSON.parse(stored) : {};
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn(
        "[DevTools] Failed to parse persisted state from sessionStorage. " +
          "Using defaults.",
        e
      );
      return {};
    }
  }

  /**
   * Save current state to sessionStorage.
   */
  #persistState() {
    try {
      window.sessionStorage?.setItem(
        DevToolsState.#SESSION_STORAGE_KEY,
        JSON.stringify({
          pluginOutletDebug: this._pluginOutletDebug,
          blockDebug: this._blockDebug,
          blockVisualOverlay: this._blockVisualOverlay,
          blockGhostBlocks: this._blockGhostBlocks,
          blockOutletBoundaries: this._blockOutletBoundaries,
          flags: Object.fromEntries(this.#flags),
        })
      );
    } catch {
      // Ignore storage errors
    }
  }

  /**
   * Enable visual overlay showing plugin outlet debug information.
   * When enabled, plugin outlets display badges and tooltips with outlet details.
   *
   * @type {boolean}
   */
  get pluginOutletDebug() {
    return this._pluginOutletDebug;
  }

  set pluginOutletDebug(value) {
    this._pluginOutletDebug = value;
    this.#persistState();
  }

  /**
   * Enable console logging of block condition evaluations.
   *
   * @type {boolean}
   */
  get blockDebug() {
    return this._blockDebug;
  }

  set blockDebug(value) {
    this._blockDebug = value;
    this.#persistState();
  }

  /**
   * Enable visual overlay showing block boundaries and info.
   *
   * @type {boolean}
   */
  get blockVisualOverlay() {
    return this._blockVisualOverlay;
  }

  set blockVisualOverlay(value) {
    this._blockVisualOverlay = value;
    this.#persistState();
  }

  /**
   * Enable ghost blocks showing hidden blocks with dashed outlines.
   *
   * @type {boolean}
   */
  get blockGhostBlocks() {
    return this._blockGhostBlocks;
  }

  set blockGhostBlocks(value) {
    this._blockGhostBlocks = value;
    this.#persistState();
  }

  /**
   * Show block outlet debug boundaries around outlets, even when no blocks
   * are rendered. This helps visualize outlet locations during development.
   *
   * @type {boolean}
   */
  get blockOutletBoundaries() {
    return this._blockOutletBoundaries;
  }

  set blockOutletBoundaries(value) {
    this._blockOutletBoundaries = value;
    this.#persistState();
  }
}

const state = new DevToolsState();
Object.preventExtensions(state);

export default state;
