import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import { compare } from "@ember/utils";
import { TrackedMap } from "@ember-compat/tracked-built-ins";

export default class A11ySkipLinks extends Service {
  @tracked show = true;

  #helpers = new TrackedMap();

  registerHelper(helper, skipLinkDefinition) {
    if (!this.#helpers.has(helper)) {
      registerDestructor(helper, () => {
        this.#helpers.delete(helper);
      });
    }

    this.#helpers.set(helper, skipLinkDefinition);
  }

  get items() {
    return [...this.#helpers.values()].sort((a, b) =>
      compare(a?.position, b?.position)
    );
  }
}
