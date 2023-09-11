import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { registerDestructor } from "@ember/destroyable";

@disableImplicitInjections
export default class BodyClassesService extends Service {
  #helpers = new Map();

  registerClasses(helper, classes) {
    if (this.#helpers.has(helper)) {
      const previousClasses = this.#helpers.get(helper);

      this.#helpers.set(helper, classes);
      this.removeUnusedClasses(previousClasses);
    } else {
      this.#helpers.set(helper, classes);

      registerDestructor(helper, () => {
        const previousClasses = this.#helpers.get(helper);
        this.#helpers.delete(helper);
        this.removeUnusedClasses(previousClasses);
      });
    }

    for (const bodyClass of classes) {
      document.body.classList.add(bodyClass);
    }
  }

  removeUnusedClasses(classes) {
    const remainingClasses = new Set([...this.#helpers.values()].flat());

    for (const bodyClass of classes) {
      if (!remainingClasses.has(bodyClass)) {
        document.body.classList.remove(bodyClass);
      }
    }
  }
}
