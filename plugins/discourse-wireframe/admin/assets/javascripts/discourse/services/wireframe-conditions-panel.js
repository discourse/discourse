// @ts-check
import { trackedObject } from "@ember/reactive/collections";
import Service from "@ember/service";

const STORAGE_KEY = "wireframe.conditions-panel";

/**
 * Holds the condition-builder floating panel's UI state: whether it's detached
 * from the inspector into a free-floating panel, and its on-screen rect. Both
 * are a user PREFERENCE persisted to localStorage so they survive reloads —
 * not session state (they are not reset on editor exit).
 *
 * A dependency-free peer service: it injects nothing and is read/commanded
 * through the orchestrator's thin facades, so the condition-panel chrome stays
 * decoupled from the rest of the editor.
 */
export default class WireframeConditionsPanelService extends Service {
  /**
   * The panel preference. `detached` is whether the condition builder floats
   * free of the inspector; `rect` is its last on-screen position/size (or
   * `null` before the user has moved it). Held in a `#`-private tracked object
   * so the getters stay reactive without exposing the mutable state.
   *
   * @type {{detached: boolean, rect: Object|null}}
   */
  #state = trackedObject({ detached: false, rect: null });

  constructor() {
    super(...arguments);
    this.#load();
  }

  /**
   * Whether the condition builder is detached into a floating panel.
   *
   * @returns {boolean}
   */
  get detached() {
    return this.#state.detached;
  }

  /**
   * The floating panel's last position/size, or `null` if it hasn't been moved.
   * A frozen copy so consumers can read/spread it without mutating service
   * state.
   *
   * @returns {Object|null}
   */
  get rect() {
    return this.#state.rect ? Object.freeze({ ...this.#state.rect }) : null;
  }

  /**
   * Collapses the floating panel back into the inspector.
   */
  close() {
    this.#state.detached = false;
    this.#persist();
  }

  /**
   * Toggles the panel between docked (in the inspector) and detached (floating).
   */
  toggleDetached() {
    this.#state.detached = !this.#state.detached;
    this.#persist();
  }

  /**
   * Records the floating panel's new position/size after a drag/resize.
   *
   * @param {Object} rect
   */
  updateRect(rect) {
    this.#state.rect = rect;
    this.#persist();
  }

  /**
   * Hydrates the panel preference from localStorage on construction. Tolerates
   * missing / malformed entries by leaving the defaults in place.
   */
  #load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) {
        return;
      }
      const parsed = JSON.parse(raw);
      if (typeof parsed?.detached === "boolean") {
        this.#state.detached = parsed.detached;
      }
      if (parsed?.rect && typeof parsed.rect === "object") {
        this.#state.rect = parsed.rect;
      }
    } catch {
      // Corrupt JSON in localStorage — ignore, keep defaults.
    }
  }

  #persist() {
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({
          detached: this.#state.detached,
          rect: this.#state.rect,
        })
      );
    } catch {
      // QuotaExceeded / disabled storage — non-fatal, the preference
      // just won't survive the session.
    }
  }
}
