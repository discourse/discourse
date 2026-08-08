import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { INPUT_DELAY } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import type SelectEngine from "discourse/ui-kit/select/select-engine";

// A source that answers faster than this never shows a placeholder, so a quick server does
// not flash one; only a wait long enough to read as "stuck" gets visible feedback.
const LOADING_FEEDBACK_DELAY = 250;
// Placeholder rows appended at the loading frontier while a server page is in flight, so a
// pending fetch reads as "more coming" in the list rather than a silent stop.
const FRONTIER_SKELETON_COUNT = 3;
// Placeholders for a load with nothing on screen to size it: enough to fill the listbox
// viewport and overflow it slightly.
const FULL_SKELETON_COUNT = 10;
// A reload mirrors the outgoing list, stopping only at nothing: a panel with no placeholders at
// all reads as broken rather than busy.
const MIN_RELOAD_SKELETON_COUNT = 1;

/** A pending-fetch placeholder row mixed into the windowed list at the loading frontier. */
export interface SkeletonRow {
  key: string;
  isSkeleton: true;
}

interface LoadFeedbackTrackerOptions {
  engine: SelectEngine;
  getDebounce: () => boolean | number;
  getSkeletonCountArg: () => number | undefined;
}

export default class LoadFeedbackTracker {
  #engine: SelectEngine;
  #frontierSkeletons: readonly SkeletonRow[] = Array.from(
    { length: FRONTIER_SKELETON_COUNT },
    (_, i) => ({ key: `__skeleton:${i}`, isSkeleton: true })
  );
  #getDebounce: () => boolean | number;
  #getSkeletonCountArg: () => number | undefined;
  #loadFeedbackTimer?: ReturnType<typeof discourseLater>;

  /** Whether a server load has run long enough to deserve a visible placeholder. */
  @tracked _loadFeedbackDue = false;

  /**
   * Rows the list last rendered, sizing a reload's skeleton. `null` means no list has rendered
   * in this panel session, which is a different case from one that rendered none.
   *
   * Tracked, and therefore recorded from a modifier rather than during render: a plain field
   * gives {@link skeletonRows} no dependency at all, so it computes once against the initial
   * `null` and Glimmer never recomputes it — the skeleton would stay at its opening size
   * forever.
   */
  @tracked _lastRenderedRowCount: number | null = null;

  constructor({
    engine,
    getDebounce,
    getSkeletonCountArg,
  }: LoadFeedbackTrackerOptions) {
    this.#engine = engine;
    this.#getDebounce = getDebounce;
    this.#getSkeletonCountArg = getSkeletonCountArg;
    registerDestructor(this, () => cancel(this.#loadFeedbackTimer));
  }

  get frontierSkeletons(): readonly SkeletonRow[] {
    return this.#frontierSkeletons;
  }

  /**
   * Distinct-keyed placeholder rows for the loading skeleton (`@skeletonCount` overrides).
   */
  get skeletonRows(): Array<{ key: number }> {
    const count = this.#getSkeletonCountArg() ?? this.#skeletonCount;
    return Array.from({ length: count }, (_, key) => ({ key }));
  }

  /**
   * Whether to append frontier skeleton placeholders for a pending reveal (a server page
   * fetched at the tail). Gated on the load-feedback delay so a fast source shows none, and
   * on `serverRevealPending` so a re-query — which replaces the set — does not.
   */
  get showRevealPlaceholder(): boolean {
    return this._loadFeedbackDue && this.#engine.serverRevealPending;
  }

  /**
   * Whether to keep the previous rows mounted while a load is in flight.
   *
   * Retention exists to absorb a fast source, where dropping to a skeleton and back reads as a
   * flicker. Past {@link LOADING_FEEDBACK_DELAY} it stops paying for itself and starts lying: a
   * re-query's rows are not merely old but *wrong* for what the input now says, and they remain
   * clickable with the cursor on one of them, so an Enter lands on a row the query excludes.
   * The skeleton has nothing to select and cannot be mistaken for an answer.
   */
  get retainRowsWhileReloading(): boolean {
    return !this.#replaceRowsWhileReloading;
  }

  /**
   * How long a load may run before it earns visible feedback.
   *
   * The wait being measured is the source's, but pending starts at the keystroke and the
   * request does not start until the debounce elapses. Counting from the keystroke charges the
   * source for the debounce, and since the default debounce already exceeds the threshold, every
   * re-query would trip it — retention would never apply and no source could be "fast".
   */
  get #loadFeedbackDelay(): number {
    const debounce = this.#getDebounce();
    const debounceDelay =
      debounce === true ? INPUT_DELAY : debounce === false ? 0 : debounce;
    return LOADING_FEEDBACK_DELAY + debounceDelay;
  }

  /**
   * Whether a re-query has been in flight long enough that the previous rows should give way to
   * the loading skeleton. Excludes a reveal, whose rows are still correct and stay put.
   */
  get #replaceRowsWhileReloading(): boolean {
    return (
      this._loadFeedbackDue &&
      this.#engine.serverPending &&
      !this.#engine.serverRevealPending
    );
  }

  /**
   * How many placeholders a load should stand up.
   *
   * Opening onto an empty panel, the skeleton describes an unknown list, so it fills the
   * viewport (20em against a ~2.4em row) and overflows slightly — a clipped last placeholder
   * reads as more content rather than as a short list.
   *
   * Replacing rows already on screen is a different claim. The list had a height and is about
   * to have another, and a four-row list that becomes nine placeholders and then two rows has
   * moved everything under the pointer twice for no reason. Mirroring what it replaces keeps
   * the panel at its own size, so the only movement is the one the new results actually cause.
   *
   * The floor is one, not zero, and exists solely for the outgoing list that was *empty*:
   * mirroring it exactly would swap the empty message for a blank panel, which reads as a
   * broken list rather than a loading one.
   */
  get #skeletonCount(): number {
    if (this._lastRenderedRowCount == null) {
      return FULL_SKELETON_COUNT;
    }
    return Math.min(
      Math.max(this._lastRenderedRowCount, MIN_RELOAD_SKELETON_COUNT),
      FULL_SKELETON_COUNT
    );
  }

  /**
   * Arms the placeholder only once a load has been pending past the threshold, so a source
   * that answers quickly shows nothing at all.
   *
   * Tracked from the panel rather than the listbox because the flag decides whether the listbox
   * exists at all ({@link retainRowsWhileReloading}). Armed from the listbox, raising it would
   * unmount the element carrying the timer, whose teardown lowers the flag again and remounts
   * it — a strobe rather than a load state. The panel spans both.
   */
  @action
  trackLoadFeedback(_element: HTMLElement, [pending]: [boolean]): void {
    cancel(this.#loadFeedbackTimer);
    if (!pending) {
      this._loadFeedbackDue = false;
      return;
    }
    this.#loadFeedbackTimer = discourseLater(
      this,
      () => (this._loadFeedbackDue = true),
      this.#loadFeedbackDelay
    );
  }

  /**
   * Cancels the load-feedback timer when the panel closes, so a torn-down instance cannot have
   * the flag flipped under it.
   */
  @action
  releaseLoadFeedback(): void {
    cancel(this.#loadFeedbackTimer);
    this._loadFeedbackDue = false;
    // Reset here rather than in `releaseListbox`: the listbox also unmounts mid-session when a
    // reload swaps in the skeleton, which is precisely when the outgoing count is needed.
    this._lastRenderedRowCount = null;
  }

  /**
   * Records how many rows the list is showing, so a reload's skeleton can be sized to what it
   * replaces. Runs from a render modifier, after render, which is what makes writing a tracked
   * field here safe.
   */
  @action
  recordRowCount(_element: HTMLElement, [count]: [number]): void {
    this._lastRenderedRowCount = count;
  }
}
