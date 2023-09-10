import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { registerDestructor } from "@ember/destroyable";

@disableImplicitInjections
export default class BodyClassesService extends Service {
  #helpers = new Map();

  registerClasses(helper, classes) {
    if (this.#helpers.has(helper)) {
      const classesToRemove = this.#helpers
        .get(helper)
        .filter((c) => !classes.includes(c));
      this.removeClasses(classesToRemove);
    } else {
      registerDestructor(helper, () => {
        const removedClasses = this.#helpers.get(helper);
        this.#helpers.delete(helper);

        this.removeClasses(removedClasses);
      });
    }

    this.#helpers.set(helper, classes);
    for (const bodyClass of classes) {
      document.body.classList.add(bodyClass);
    }
  }

  removeClasses(classes) {
    const currentClasses = new Set(...this.#helpers.values());

    for (const bodyClass of classes) {
      if (!currentClasses.has(bodyClass)) {
        document.body.classList.remove(bodyClass);
      }
    }
  }
}
