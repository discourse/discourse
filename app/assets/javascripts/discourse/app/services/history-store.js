import Service, { inject as service } from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { bind } from "discourse-common/utils/decorators";

const HISTORY_SIZE = 100;
const HISTORIC_KEY = Symbol("historic");

/**
 * This service provides a key-value store which can store per-route information.
 * When navigating 'back' via browser controls, the service will restore the data
 * for the appropriate route.
 */
@disableImplicitInjections
export default class HistoryStore extends Service {
  @service router;

  #routeData = new Map();
  #uuid;
  #route;

  constructor() {
    super(...arguments);
    this.router.on("routeDidChange", this.maybeRouteDidChange);
  }

  get #data() {
    // Check if route changed since we last checked the uuid.
    // This can happen if some other logic has a routeDidChange
    // handler that runs before ours.
    this.maybeRouteDidChange();

    const uuid = this.#uuid;

    let data = this.#routeData.get(uuid);
    if (data) {
      return data;
    }

    data = new TrackedMap();
    this.#routeData.set(uuid, data);
    this.#pruneOldData();

    return data;
  }

  get isPoppedState() {
    return !!this.get(HISTORIC_KEY);
  }

  get(key) {
    return this.#data.get(key);
  }

  set(key, value) {
    return this.#data.set(key, value);
  }

  delete(key) {
    return this.#data.delete(key);
  }

  #pruneOldData() {
    while (this.#routeData.size > HISTORY_SIZE) {
      // JS Map guarantees keys will be returned in insertion order
      const oldestUUID = this.#routeData.keys().next().value;
      this.#routeData.delete(oldestUUID);
    }
  }

  @bind
  maybeRouteDidChange() {
    if (this.#route === this.router.currentRoute) {
      return;
    }
    this.#route = this.router.currentRoute;
    this.#routeData.get(this.#uuid)?.set(HISTORIC_KEY, true);

    const newUuid = window.history.state?.uuid;

    if (this.#uuid === newUuid) {
      // A refresh. Clear the state
      this.#routeData.delete(newUuid);
    }

    this.#uuid = newUuid;
  }

  willDestroy() {
    this.router.off("routeDidChange", this.maybeRouteDidChange);
  }
}
