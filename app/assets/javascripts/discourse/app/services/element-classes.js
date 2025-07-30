import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class ElementClassesService extends Service {
  /** @type Map<Helper, { element: Element, classes: string[] }> */
  #helpers = new Map();

  registerClasses(helper, element, classes) {
    if (this.#helpers.has(helper)) {
      const previousClasses = this.#helpers.get(helper).classes;

      this.#helpers.set(helper, { classes, element });
      this.removeUnusedClasses(element, previousClasses);
    } else {
      this.#helpers.set(helper, { classes, element });

      registerDestructor(helper, () => {
        const previousClasses = this.#helpers.get(helper).classes;
        this.#helpers.delete(helper);
        this.removeUnusedClasses(element, previousClasses);
      });
    }

    for (const elementClass of classes) {
      element.classList.add(elementClass);
    }
  }

  removeUnusedClasses(element, classes) {
    const remainingClasses = new Set(
      ...this.#helpers
        .values()
        .filter(({ element: el }) => el === element)
        .flatMap(({ classes: cls }) => cls)
    );

    for (const elementClass of classes) {
      if (!remainingClasses.has(elementClass)) {
        element.classList.remove(elementClass);
      }
    }
  }
}
