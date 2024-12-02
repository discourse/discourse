import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import { TrackedSet } from "tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class FooterService extends Service {
  #hiders = new TrackedSet();
  @tracked _showFooterOverride = null;

  get showFooter() {
    return this._showFooterOverride ?? this.#hiders.size === 0;
  }

  set showFooter(value) {
    if (value === true) {
      this._showFooterOverride = null;
    } else {
      this._showFooterOverride = value;
    }
  }

  registerHider(destroyable) {
    this.#hiders.add(destroyable);
    registerDestructor(destroyable, () => this.#hiders.delete(destroyable));
  }
}
