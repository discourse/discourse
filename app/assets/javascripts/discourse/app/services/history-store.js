import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { isTesting } from "discourse-common/config/environment";
import { bind } from "discourse-common/utils/decorators";

const HISTORY_SIZE = 100;
const HISTORIC_KEY = Symbol("historic");
const HANDLED_TRANSITIONS = new WeakSet();

/**
 * This service provides a key-value store which can store per-route information.
 * When navigating 'back' via browser controls, the service will restore the data
 * for the appropriate route.
 */
@disableImplicitInjections
export default class HistoryStore extends Service {
  @service router;

  #routeData = new TrackedMap();
  #uuid;
  #pendingStore = DEBUG && isTesting() ? new TrackedMap() : null;

  get #currentStore() {
    return this.#pendingStore || this.#dataFor(this.#uuid);
  }

  /**
   * Identify if the current route was accessed via the browser back/forward buttons
   * @returns {boolean}
   */
  get isPoppedState() {
    return !!this.get(HISTORIC_KEY);
  }

  /**
   * Fetch a value from the current route's key/value store
   */
  get(key) {
    return this.#currentStore.get(key);
  }

  /**
   * Set a value in the current route's key/value store. Will persist for the lifetime
   * of the route, and will be restored if the user navigates 'back' to the route.
   */
  set(key, value) {
    return this.#currentStore.set(key, value);
  }

  /**
   * Delete a value from the current route's key/value store
   */
  delete(key) {
    return this.#currentStore.delete(key);
  }

  @cached
  get hasFutureEntries() {
    // Keys will be returned in insertion order. Return true if there is any key **after** the current one
    let foundCurrent = false;
    for (const key of this.#routeData.keys()) {
      if (foundCurrent) {
        return true;
      }

      if (key === this.#uuid) {
        foundCurrent = true;
      }
    }
    return false;
  }

  @cached
  get hasPastEntries() {
    // Keys will be returned in insertion order. Return false if we find the current uuid before any other
    for (const key of this.#routeData.keys()) {
      if (key === undefined) {
        continue;
      }
      return key !== this.#uuid;
    }
  }

  #pruneOldData() {
    while (this.#routeData.size > HISTORY_SIZE) {
      // JS Map guarantees keys will be returned in insertion order
      const oldestUUID = this.#routeData.keys().next().value;
      this.#routeData.delete(oldestUUID);
    }
  }

  #dataFor(uuid) {
    let data = this.#routeData.get(uuid);
    if (data) {
      return data;
    }

    data = new TrackedMap();
    this.#routeData.set(uuid, data);
    this.#pruneOldData();

    return data;
  }

  /**
   * Called by the Application route when its willResolveModel hook
   * is triggered by the ember router. Unfortunately this hook is
   * not available as an event on the router service.
   */
  @bind
  willResolveModel(transition) {
    if (HANDLED_TRANSITIONS.has(transition)) {
      return;
    }
    HANDLED_TRANSITIONS.add(transition);

    if (DEBUG && isTesting()) {
      // Can't use window.history in tests
      return;
    }

    this.set(HISTORIC_KEY, true);

    let pendingStoreForThisTransition;

    if (this.#uuid === window.history.state?.uuid) {
      // A normal ember transition. The history uuid will only change **after** models are resolved.
      // To allow routes to store data for the upcoming uuid, we set up a temporary data store
      // and then persist it if/when the transition succeeds.
      pendingStoreForThisTransition = new TrackedMap();
    } else {
      // A transition initiated by the browser back/forward buttons. We might already have some stored
      // data for this route. If so, take a copy of it and use that as the pending store. As with normal transitions,
      // it'll be persisted if/when the transition succeeds.
      pendingStoreForThisTransition = new TrackedMap(
        this.#dataFor(window.history.state?.uuid)?.entries()
      );
    }

    this.#pendingStore = pendingStoreForThisTransition;
    transition
      .then(() => {
        this.#uuid = window.history.state?.uuid;
        this.#routeData.set(this.#uuid, this.#pendingStore);
        this.#pruneOldData();
      })
      .finally(() => {
        if (pendingStoreForThisTransition === this.#pendingStore) {
          this.#pendingStore = null;
        }
      });
  }
}
