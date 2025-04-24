import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import SessionStore from "discourse/lib/session-store";

const PROXIED_METHODS = Object.getOwnPropertyNames(
  SessionStore.prototype
).reject((p) => p === "constructor");

@disableImplicitInjections
export default class SessionStoreService extends Service {
  _SessionStore = new SessionStore("discourse_");

  constructor() {
    super(...arguments);

    for (const name of PROXIED_METHODS) {
      this[name] = this._SessionStore[name].bind(this._SessionStore);
    }
  }
}
