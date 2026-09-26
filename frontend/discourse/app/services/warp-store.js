import { getOwner } from "@ember/owner";
import Service from "discourse/lib/service";

let Impl;
let loading;

// Called by the store implementation module when it evaluates.
export function registerWarpStoreClass(klass) {
  Impl = klass;
}

// A route bundle whose code pushes into the store synchronously loads the
// implementation alongside its modules, so `push` and `peekRecord` never wait.
export default class WarpStore extends Service {
  #store;

  get loaded() {
    return Boolean(Impl);
  }

  peekRecord(...args) {
    return this.#impl().peekRecord(...args);
  }

  push(...args) {
    return this.#impl().push(...args);
  }

  async request(...args) {
    return (await this.load()).request(...args);
  }

  async load() {
    if (!Impl) {
      loading ??= import("discourse/data/warp-store-impl");
      await loading;
    }
    return this.#impl();
  }

  #impl() {
    if (!this.#store) {
      if (!Impl) {
        throw new Error(
          "The WarpDrive store is used synchronously before its bundle loaded"
        );
      }
      const owner = getOwner(this);
      owner.register("service:warp-store-impl", Impl);
      this.#store = owner.lookup("service:warp-store-impl");
    }
    return this.#store;
  }
}
