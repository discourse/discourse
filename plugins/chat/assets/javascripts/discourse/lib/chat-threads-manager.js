import { inject as service } from "@ember/service";
import { setOwner } from "@ember/application";
import Promise from "rsvp";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";
import { tracked } from "@glimmer/tracking";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { popupAjaxError } from "discourse/lib/ajax-error";

/*
  The ChatThreadsManager is responsible for managing the loaded chat threads
  for a ChatChannel model.

  It provides helpers to facilitate using and managing loaded threads instead of constantly
  fetching them from the server.
*/

export default class ChatThreadsManager {
  @service chatSubscriptionsManager;
  @service chatApi;
  @service currentUser;
  @tracked _cached = new TrackedObject();

  constructor(owner) {
    setOwner(this, owner);
  }

  async find(channelId, threadId, options = { fetchIfNotFound: true }) {
    const existingThread = this.#findStale(threadId);
    if (existingThread) {
      return Promise.resolve(existingThread);
    } else if (options.fetchIfNotFound) {
      return this.#find(channelId, threadId);
    } else {
      return Promise.resolve();
    }
  }

  get threads() {
    return Object.values(this._cached);
  }

  store(threadObject) {
    let model = this.#findStale(threadObject.id);

    if (!model) {
      model = new ChatThread(threadObject);
      this.#cache(model);
    }

    return model;
  }

  async #find(channelId, threadId) {
    return this.chatApi
      .thread(channelId, threadId)
      .catch(popupAjaxError)
      .then((thread) => {
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
