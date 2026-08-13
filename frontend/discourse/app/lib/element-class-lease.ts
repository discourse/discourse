interface LeaseState {
  holders: number;
  removeOnRelease: boolean;
}

const leases = new WeakMap<Element, Map<string, LeaseState>>();

/**
 * Holds one class on an element until every cooperating owner releases it.
 * A class that predates the first lease is preserved after the final release.
 */
export default class ElementClassLease {
  #className: string;
  #element: Element;
  #released = false;

  constructor(element: Element, className: string) {
    this.#element = element;
    this.#className = className;

    let elementLeases = leases.get(element);
    if (!elementLeases) {
      elementLeases = new Map();
      leases.set(element, elementLeases);
    }

    const state = elementLeases.get(className);
    if (state) {
      state.holders += 1;
      return;
    }

    const removeOnRelease = !element.classList.contains(className);
    if (removeOnRelease) {
      element.classList.add(className);
    }
    elementLeases.set(className, { holders: 1, removeOnRelease });
  }

  release() {
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
