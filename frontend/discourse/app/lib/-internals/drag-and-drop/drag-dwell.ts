import {
  isDestroyed,
  isDestroying,
  registerDestructor,
} from "@ember/destroyable";
import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

const EMPTY = Symbol("empty drag dwell");

/** The dwell delay used when the consumer does not pick one. */
const DEFAULT_DELAY = 500;

/** Options for {@link createDragDwell}. */
export interface DragDwellOptions<Target> {
  /**
   * Object whose lifetime bounds the dwell, usually the component or service
   * that owns it. Destruction cancels a pending dwell and prevents later
   * reports from firing.
   */
  destroyable: object;

  /**
   * Milliseconds of uninterrupted same-identity candidacy required before
   * {@link DragDwellOptions.onDwell} fires. Defaults to `500`. The delay is
   * scheduled through `discourseLater`, so it collapses to a short wait under
   * test.
   */
  delay?: number;

  /**
   * Maps a candidate to the key compared with `Object.is`. Defaults to the
   * candidate itself. Called only for non-null candidates; `null` and
   * `undefined` are both valid returned keys. Must be pure for a target.
   */
  identity?: (target: Target) => unknown;

  /**
   * Fires once after an uninterrupted candidacy, with the most recent object
   * reported for that identity. A throw leaves the identity latched, so it
   * cannot fire again until cleared.
   */
  onDwell: (target: Target) => void;
}

/** A live dwell tracker returned by {@link createDragDwell}. */
export interface DragDwell<Target> {
  /**
   * Reports the current candidate, or `null` to clear it. A report with the
   * same identity refreshes only the retained object: it neither pushes the
   * deadline back nor rearms a dwell that already fired. A new identity
   * cancels any pending dwell and starts a fresh delay.
   */
  update(target: Target | null): void;

  /**
   * Cancels any pending dwell and clears its latched identity. Equivalent to
   * `update(null)` and safe to call repeatedly.
   */
  reset(): void;
}

/**
 * Tracks how long one candidate identity remains current during a drag.
 * Consumers can feed it equally from a drop target's enter/leave callbacks or
 * a monitor's per-frame hit-testing. Silence (not calling {@link DragDwell.update})
 * is not `update(null)` and therefore does not interrupt a pending dwell.
 *
 * `Target` must be non-nullish: `null` is reserved as the clear sentinel.
 *
 * Guide to choosing between the drag and gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 *
 * @see The `dDragDwell` modifier, which packages this for the common case of
 *   one element observed through the drag monitors.
 *
 * @param options - The dwell timing, lifetime, identity, and callback.
 * @returns A tracker for reporting and clearing the current candidate.
 */
export default function createDragDwell<Target>(
  options: DragDwellOptions<Target>
): DragDwell<Target> {
  const { delay = DEFAULT_DELAY, destroyable, identity, onDwell } = options;
  let currentKey: unknown | typeof EMPTY = EMPTY;
  let latestTarget: Target | null = null;
  let timer: ReturnType<typeof discourseLater> | null = null;

  function reset() {
    if (currentKey === EMPTY) {
      return;
    }

    cancel(timer ?? undefined);
    timer = null;
    currentKey = EMPTY;
    latestTarget = null;
  }

  function update(target: Target | null) {
    if (target === null) {
      reset();
      return;
    }

    const key = identity ? identity(target) : target;
    if (Object.is(key, currentKey)) {
      latestTarget = target;
      return;
    }

    cancel(timer ?? undefined);
    currentKey = key;
    latestTarget = target;
    timer = discourseLater(() => {
      // This order is load-bearing and must not be reordered.
      timer = null;
      if (isDestroying(destroyable) || isDestroyed(destroyable)) {
        return;
      }

      onDwell(latestTarget as Target);
      // Retain the target: clearing it would corrupt a reentrant re-arm from onDwell.
    }, delay);
  }

  registerDestructor(destroyable, reset);

  return { reset, update };
}
