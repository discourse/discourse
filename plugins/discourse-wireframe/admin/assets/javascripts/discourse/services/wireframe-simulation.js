// @ts-check

import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

/**
 * Holds the editor's simulation slot — a `{user, viewport}` preview persona the
 * condition evaluator reads (via the EVAL_CONTEXT hook) so condition-gated
 * blocks render as if the simulated user / viewport were active. Block bodies
 * themselves still render with the real user's data; simulation is
 * condition-only.
 *
 * A standalone service so any consumer (the simulation controls, the condition
 * evaluator wiring) injects it directly without reaching through the editor
 * kernel. It depends on nothing — to signal the kernel's page-wide re-render
 * dep on a change, the kernel registers a callback via `registerOnChange`
 * (one-way: the kernel knows this service, never the reverse), so there is no
 * dependency cycle.
 */
export default class WireframeSimulationService extends Service {
  // The kernel registers a callback here (via `registerOnChange`) so a
  // simulation change can bump its page-wide `structuralVersion`. Null until
  // registered; mutations no-op the signal until then (a missed bump only
  // means no extra refresh, never wrong data).
  #onChange = null;

  // The slot, shape `{ user, viewport }` (each null for "use the real value")
  // or null when no slot is set. Reassigned wholesale on every change — never
  // mutated in place — so the presence-vs-null key semantics stay intact.
  @tracked _simulation = null;

  /**
   * The current simulation slot, or `null` when simulation is off. Read-only:
   * the slot is replaced wholesale on each change, never mutated through this.
   *
   * @returns {{user: Object|null, viewport: {viewport: Object, touch: boolean}|null}|null}
   */
  get value() {
    return this._simulation;
  }

  /**
   * Whether simulation mode is currently active (any slot is set).
   *
   * @returns {boolean}
   */
  get isSimulating() {
    return this._simulation != null;
  }

  /**
   * Registers the callback the kernel uses to bump its page-wide re-render dep
   * whenever the simulation changes. Called once by the kernel; a later call
   * replaces the previous handler.
   *
   * @param {() => void} fn
   */
  registerOnChange(fn) {
    this.#onChange = fn;
  }

  /**
   * Sets the persona portion of the simulation.
   *
   * Three states:
   *   - `undefined` → clears the persona slot (real `currentUser` is used).
   *   - `null` → simulates an anonymous viewer.
   *   - `{...}` → simulates that specific user object.
   *
   * @param {Object|null|undefined} user
   */
  setUser(user) {
    this._simulation = this.#patch(this._simulation, "user", user);
    this.#onChange?.();
  }

  /**
   * Sets the viewport portion of the simulation. Pass `undefined` to clear it
   * and fall back to the real `capabilities` service.
   *
   * @param {{viewport: Object, touch: boolean}|null|undefined} viewport
   */
  setViewport(viewport) {
    this._simulation = this.#patch(this._simulation, "viewport", viewport);
    this.#onChange?.();
  }

  /**
   * Clears both the persona and viewport slots, exiting simulation mode.
   */
  clear() {
    this._simulation = null;
    this.#onChange?.();
  }

  /**
   * Applies a single-key patch to the simulation slot. Treats `undefined` as
   * "delete the key" (since `null` is the meaningful sentinel for anonymous /
   * real). When every slot is unset, returns `null` so `isSimulating` flips to
   * `false` cleanly.
   *
   * @param {Object|null} current
   * @param {string} key
   * @param {*} value
   * @returns {Object|null}
   */
  #patch(current, key, value) {
    const next = { ...(current ?? {}) };
    if (value === undefined) {
      delete next[key];
    } else {
      next[key] = value;
    }
    if (!("user" in next) && !("viewport" in next)) {
      return null;
    }
    // Freeze the slot so the `value` getter (read on every condition
    // evaluation) can hand out the live object without a consumer mutating
    // our state — frozen once here, not copied per read.
    return Object.freeze(next);
  }
}
