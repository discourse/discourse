import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class ElementClassesService extends Service {
  /** @type Map<Helper, string[]> */
  #helpers = new Map();

  registerClasses(helper, element, classes) {
    if (this.#helpers.has(helper)) {
      const previousClasses = this.#helpers.get(helper);

      this.#helpers.set(helper, classes);
      this.removeUnusedClasses(element, previousClasses);
    } else {
      this.#helpers.set(helper, classes);

      registerDestructor(helper, () => {
        const previousClasses = this.#helpers.get(helper);
        this.#helpers.delete(helper);
        this.removeUnusedClasses(element, previousClasses);
      });
    }

    for (const elementClass of classes) {
      element.classList.add(elementClass);
    }
  }

  removeUnusedClasses(element, classes) {
    const remainingClasses = new Set([...this.#helpers.values()].flat());

    for (const elementClass of classes) {
      if (!remainingClasses.has(elementClass)) {
        element.classList.remove(elementClass);
      }
    }
  }
}
