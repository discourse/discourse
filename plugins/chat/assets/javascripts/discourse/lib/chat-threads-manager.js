import { cached, tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import Promise from "rsvp";
import { TrackedMap, TrackedObject } from "tracked-built-ins";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";

/*
  The ChatThreadsManager is responsible for managing the loaded chat threads
  for a ChatChannel model.

  It provides helpers to facilitate using and managing loaded threads instead of constantly
  fetching them from the server.
*/

export default class ChatThreadsManager {
  @service chatTrackingStateManager;
  @service chatChannelsManager;
  @service chatApi;

  @tracked _cached = new TrackedObject();
  @tracked _unreadThreadOverview = new TrackedMap();

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
    this.unreadThreadOverview.set(
      parseInt(threadId, 10),
      new Date(lastReplyCreatedAt)
    );
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
      return this.#fetchFromServer(channelId, threadId);
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

    if (threadObject?.meta?.message_bus_last_ids?.thread_message_bus_last_id) {
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
