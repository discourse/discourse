import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { registerDestructor } from "@ember/destroyable";

@disableImplicitInjections
export default class BodyClassesService extends Service {
  #helpers = new Map();

  registerClasses(helper, classes) {
    this.#helpers.set(helper, classes);

    for (const bodyClass of classes) {
      document.body.classList.add(bodyClass);
    }

    registerDestructor(helper, () => {
      const removedClasses = this.#helpers.get(helper);
      this.#helpers.delete(helper);

      const currentClasses = new Set(...this.#helpers.values());

      for (const bodyClass of removedClasses) {
        if (!currentClasses.has(bodyClass)) {
          document.body.classList.remove(bodyClass);
        }
      }
    });
  }
}
