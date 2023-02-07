import Service, { inject as service } from "@ember/service";
import Promise from "rsvp";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";
import { tracked } from "@glimmer/tracking";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { popupAjaxError } from "discourse/lib/ajax-error";

/*
  The ChatThreadsManager service is responsible for managing the loaded chat threads
  for the current chat channel.

  It provides helpers to facilitate using and managing loaded threads instead of constantly
  fetching them from the server.
*/

export default class ChatThreadsManager extends Service {
  @service chatSubscriptionsManager;
  @service chatApi;
  @service currentUser;
  @tracked _cached = new TrackedObject();

  async find(id, options = { fetchIfNotFound: true }) {
    const existingThread = this.#findStale(id);
    if (existingThread) {
      return Promise.resolve(existingThread);
    } else if (options.fetchIfNotFound) {
      return this.#find(id);
    } else {
      return Promise.resolve();
    }
  }

  // whenever the active channel changes, do this
  resetCache() {
    this._cached = new TrackedObject();
  }

  get threads() {
    return Object.values(this._cached);
  }

  store(threadObject) {
    let model = this.#findStale(threadObject.id);

    if (!model) {
      model = ChatThread.create(threadObject);
      this.#cache(model);
    }

    return model;
  }

  async #find(id) {
    return this.chatApi
      .thread(id)
      .catch(popupAjaxError)
      .then((thread) => {
        this.#cache(thread);
        return thread;
      });
  }

  #cache(thread) {
    this._cached[thread.id] = thread;
  }

  #findStale(id) {
    return this._cached[id];
  }
}
