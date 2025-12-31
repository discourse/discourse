import { tracked } from "@glimmer/tracking";

/**
 * Singleton class that manages the state of developer tools.
 * State is persisted to sessionStorage so it survives page refreshes
 * but not browser restarts. Each property is tracked for reactivity.
 *
 * @class DevToolsState
 */
class DevToolsState {
  static #SESSION_STORAGE_KEY = "discourse__dev_tools_state";

  // Private backing fields for tracked properties.
  // These are @tracked so that Glimmer re-renders when values change.
  @tracked _pluginOutletDebug;
  @tracked _blockDebug;
  @tracked _blockVisualOverlay;
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
    this._blockOutletBoundaries = persisted.blockOutletBoundaries ?? false;
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
    } catch {
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
          blockOutletBoundaries: this._blockOutletBoundaries,
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
   * Show block outlet boundaries even when empty.
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
