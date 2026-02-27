import { cached, tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { trackedMap, trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import Promise from "rsvp";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";

/*
  The ChatThreadsManager is responsible for managing the loaded chat threads
  for a ChatChannel model.

  It provides helpers to facilitate using and managing loaded threads instead of constantly
  fetching them from the server.
*/

export default class ChatThreadsManager {
  @service chatChannelsManager;
  @service chatApi;

  @tracked _cached = trackedObject();
  @tracked _unreadThreadOverview = trackedMap();

  constructor(owner) {
    setOwner(this, owner);
  }

  get unreadThreadCount() {
    return this.unreadThreadOverview.size;
  }

  get unreadThreadOverview() {
    return this._unreadThreadOverview;
  }

  set unreadThreadOverview(unreadThreadOverview) {
    this._unreadThreadOverview.clear();

    for (const [threadId, lastReplyCreatedAt] of Object.entries(
      unreadThreadOverview
    )) {
      this.markThreadUnread(threadId, lastReplyCreatedAt);
    }
  }

  markThreadUnread(threadId, lastReplyCreatedAt) {
    const id = parseInt(threadId, 10);

    // Delete first to ensure the collection tag is dirtied. Ember's native
    // trackedMap().set() only dirties the collection tag for new key insertions,
    // not for updates to existing keys. Getters that iterate via .values()
    // (like unreadThreadsCountSinceLastViewed) consume the collection tag, so
    // they would miss updates to existing entries without this workaround.
    this.unreadThreadOverview.delete(id);
    this.unreadThreadOverview.set(id, new Date(lastReplyCreatedAt));
  }

  @cached
  get threads() {
    return Object.values(this._cached);
  }

  async find(channelId, threadId, options = { fetchIfNotFound: true }) {
    const existingThread = this.#getFromCache(threadId);

    if (existingThread) {
      return Promise.resolve(existingThread);
    } else if (options.fetchIfNotFound) {
      return await this.#fetchFromServer(channelId, threadId);
    } else {
      return Promise.resolve();
    }
  }

  remove(threadObject) {
    delete this._cached[threadObject.id];
  }

  add(channel, threadObject, options = {}) {
    let model;

    if (!options.replace) {
      model = this.#getFromCache(threadObject.id);
    }

    if (!model) {
      if (threadObject instanceof ChatThread) {
        model = threadObject;
      } else {
        model = ChatThread.create(channel, threadObject);
      }

      this.#cache(model);
    }

    if (
      threadObject?.meta?.message_bus_last_ids?.thread_message_bus_last_id !==
      undefined
    ) {
      model.threadMessageBusLastId =
        threadObject.meta.message_bus_last_ids.thread_message_bus_last_id;
    }

    return model;
  }

  #cache(thread) {
    this._cached[thread.id] = thread;
  }

  #getFromCache(id) {
    return this._cached[id];
  }

  async #fetchFromServer(channelId, threadId) {
    return this.chatApi.thread(channelId, threadId).then((result) => {
      return this.chatChannelsManager.find(channelId).then((channel) => {
        return channel.threadsManager.add(channel, result.thread);
      });
    });
  }
}
