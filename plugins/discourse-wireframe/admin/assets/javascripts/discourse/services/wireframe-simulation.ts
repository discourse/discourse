import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import type {
  ConditionSimulation,
  ViewportCapabilities,
} from "discourse/blocks/conditions/condition";
import type WireframeLayoutSignalService from "./wireframe-layout-signal";

/**
 * Holds the editor's simulation slot — a `{user, viewport}` preview persona the
 * condition evaluator reads (via the EVAL_CONTEXT hook) so condition-gated
 * blocks render as if the simulated user / viewport were active. Block bodies
 * themselves still render with the real user's data; simulation is
 * condition-only.
 *
 * A standalone service so any consumer (the simulation controls, the condition
 * evaluator wiring) injects it directly without reaching through the editor
 * orchestrator. On a change it bumps the shared layout signal so every surface that
 * tracks the resolved layout re-runs (a simulation toggle changes what
 * condition-gated blocks resolve to). Its only dependency is that signal, which
 * depends on nothing — so the graph stays acyclic.
 */
export default class WireframeSimulationService extends Service {
  /** Invalidates resolved layouts after the simulated context changes. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  /**
   * Current immutable simulation slot, or `null` while simulation is disabled.
   * Reassigned wholesale so presence-versus-null semantics remain observable.
   */
  @tracked _simulation: Readonly<ConditionSimulation> | null = null;

  /**
   * The current simulation slot, or `null` when simulation is off. Read-only:
   * the slot is replaced wholesale on each change, never mutated through this.
   *
   */
  get value(): Readonly<ConditionSimulation> | null {
    return this._simulation;
  }

  /**
   * Whether simulation mode is currently active (any slot is set).
   *
   */
  get isSimulating(): boolean {
    return this._simulation != null;
  }

  /**
   * Sets the persona portion of the simulation.
   *
   * Three states:
   *   - `undefined` → clears the persona slot (real `currentUser` is used).
   *   - `null` → simulates an anonymous viewer.
   *   - `{...}` → simulates that specific user object.
   *
   * @param user - Simulated user, `null` for anonymous, or `undefined` to clear.
   */
  setUser(user: unknown): void {
    this._simulation = this.#patch(this._simulation, "user", user);
    this.wireframeLayoutSignal.bump();
  }

  /**
   * Sets the viewport portion of the simulation. Pass `undefined` to clear it
   * and fall back to the real `capabilities` service.
   *
   * @param viewport - Simulated capabilities, or a nullish value to clear.
   */
  setViewport(viewport: ViewportCapabilities | null | undefined): void {
    this._simulation = this.#patch(this._simulation, "viewport", viewport);
    this.wireframeLayoutSignal.bump();
  }

  /**
   * Clears both the persona and viewport slots, exiting simulation mode.
   */
  clear(): void {
    this._simulation = null;
    this.wireframeLayoutSignal.bump();
  }

  /**
   * Applies a single-key patch to the simulation slot. Treats `undefined` as
   * "delete the key" (since `null` is the meaningful sentinel for anonymous /
   * real). When every slot is unset, returns `null` so `isSimulating` flips to
   * `false` cleanly.
   *
   * @param current - Existing immutable simulation slot.
   * @param key - Slot being replaced.
   * @param value - New slot value, or `undefined` to remove it.
   * @returns The next immutable slot, or `null` when every slot is absent.
   */
  #patch<Key extends keyof ConditionSimulation>(
    current: Readonly<ConditionSimulation> | null,
    key: Key,
    value: ConditionSimulation[Key]
  ): Readonly<ConditionSimulation> | null {
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
