import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import KeyValueStore from "discourse/lib/key-value-store";

const PROXIED_METHODS = Object.getOwnPropertyNames(
  KeyValueStore.prototype
).reject((p) => p === "constructor");

/**
 * This is the global key-value-store which is injectable as a service.
 * Alternatively, consumers can use `discourse/lib/key-value-store` directly
 * to create their own namespaced store.
 * */
@disableImplicitInjections
export default class KeyValueStoreService extends Service {
  _keyValueStore = new KeyValueStore("discourse_");

  constructor() {
    super(...arguments);

    for (const name of PROXIED_METHODS) {
      this[name] = this._keyValueStore[name].bind(this._keyValueStore);
    }
  }
}
