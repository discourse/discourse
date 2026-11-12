/** Bookkeeping for one class token on one element. */
interface LeaseState {
  holders: number;

  /**
   * False when the class was already on the element before the first lease, so
   * an owner outside this registry does not lose its class when ours ends.
   */
  removeOnRelease: boolean;
}

/** Module-global, so leases coordinate across every caller on the page. */
let leases = new WeakMap<Element, Map<string, LeaseState>>();

/**
 * Drops all lease bookkeeping. For tests only: `document.body` outlives every
 * test, so one unreleased lease pins `holders` above zero and sends every later
 * lease on that token down the increment path for the rest of the run.
 */
export function resetElementClassLeasesForTesting() {
  leases = new WeakMap();
}

/**
 * Holds one class on an element until every cooperating owner releases it.
 * A class that predates the first lease is preserved after the final release.
 *
 * Distinct from `discourse/services/element-classes`, which arbitrates the same
 * DOM property for the `body-class`/`html-class`/`element-class` helpers: that
 * service needs an owner, and removes a class regardless of who put it there.
 * Reach for it from a component or helper, and for a lease from plain functions
 * and from code that must not clobber a class it did not add. The two
 * registries do not see each other, so never split one token across both.
 */
export default class ElementClassLease {
  #className: string;
  #element: Element;
  #released = false;

  /**
   * Takes a lease, adding the class if this is the first holder.
   *
   * @param className - A single class token.
   * @throws A `DOMException` if the DOM rejects `className` (whitespace or
   *   empty). It throws before any bookkeeping is recorded, so construct inside
   *   a `try` when the token is not a literal.
   */
  constructor(element: Element, className: string) {
    this.#element = element;
    this.#className = className;

    const held = leases.get(element)?.get(className);
    if (held) {
      // Re-asserted rather than assumed from the count, so a class removed by
      // anything outside this registry comes back for the next holder.
      element.classList.add(className);
      held.holders += 1;
      return;
    }

    const removeOnRelease = !element.classList.contains(className);
    if (removeOnRelease) {
      // Before the registry is touched, so a token the DOM rejects leaves no
      // entry behind to be released later.
      element.classList.add(className);
    }

    let elementLeases = leases.get(element);
    if (!elementLeases) {
      elementLeases = new Map();
      leases.set(element, elementLeases);
    }
    elementLeases.set(className, { holders: 1, removeOnRelease });
  }

  /**
   * Gives up this lease, removing the class once the last holder has released
   * and the class did not predate the first lease. Idempotent, so a caller may
   * release from both a normal path and a teardown path without tracking which
   * ran.
   */
  release(): void {
    if (this.#released) {
      return;
    }
    this.#released = true;

    const elementLeases = leases.get(this.#element);
    const state = elementLeases?.get(this.#className);
    if (!elementLeases || !state) {
      return;
    }

    state.holders -= 1;
    if (state.holders > 0) {
      return;
    }

    elementLeases.delete(this.#className);
    if (elementLeases.size === 0) {
      leases.delete(this.#element);
    }
    if (state.removeOnRelease) {
      this.#element.classList.remove(this.#className);
    }
  }
}
