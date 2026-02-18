import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import EmbedMode from "discourse/lib/embed-mode";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class FooterService extends Service {
  #hiders = new TrackedSet();
  @tracked _showFooterOverride = null;

  get showFooter() {
    if (EmbedMode.enabled) {
      return false;
    }
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
