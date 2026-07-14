// @ts-check

import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

/**
 * A monotonic "the resolved layout changed" beacon. Every structural mutation
 * (and a simulation toggle, which changes what condition-gated blocks resolve
 * to) bumps it; editor surfaces that derive from the live layout open a tracked
 * dependency on `version` so they re-run on any such change.
 *
 * It exists as its own peer service rather than living on any one concern
 * because both the selection and the edit/undo concerns need to read AND raise
 * it: if either owned it, the other would have to depend on that owner and the
 * two would form a cycle. A standalone signal that everyone reads downward
 * keeps the graph acyclic. It depends on nothing.
 */
export default class WireframeLayoutSignalService extends Service {
  // The beacon counter. `_`-prefixed because `@tracked` can't decorate a `#`
  // field and it's read only through the `version` getter — never written from
  // outside `bump`.
  @tracked _version = 0;

  /**
   * The current revision. Read this in a getter/template to re-run on the next
   * layout change. Read-only: callers signal a change via `bump`, never by
   * assigning.
   *
   * @returns {number}
   */
  get version() {
    return this._version;
  }

  /**
   * Signals that the resolved layout changed, so every consumer tracking
   * `version` re-evaluates.
   */
  bump() {
    this._version++;
  }
}
