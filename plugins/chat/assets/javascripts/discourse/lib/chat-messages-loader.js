import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  DEFAULT_MESSAGE_PAGE_SIZE,
  FUTURE,
  PAST,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatMessagesLoader {
  @service chatApi;

  @tracked loading = false;
  @tracked canLoadMorePast = false;
  @tracked canLoadMoreFuture = false;
  @tracked fetchedOnce = false;

  // Edges of what the server has returned, kept apart from the rendered list
  // because live messages can be appended past a gap in it.
  #oldestFetchedMessageId = null;
  #newestFetchedMessageId = null;

  constructor(owner, model) {
    setOwner(this, owner);
    this.model = model;
  }

  get loadedPast() {
    return this.canLoadMorePast === false && this.fetchedOnce;
  }

  async loadMore(args = {}) {
    if (this.canLoadMoreFuture === false && args.direction === FUTURE) {
      return;
    }

    if (this.canLoadMorePast === false && args.direction === PAST) {
      return;
    }

    args = {
      direction: args.direction,
      page_size: DEFAULT_MESSAGE_PAGE_SIZE,
      target_message_id:
        args.direction === PAST
          ? this.#oldestFetchedMessageId
          : this.#newestFetchedMessageId,
    };

    args = this.#cleanArgs(args);

    let result;
    try {
      this.loading = true;
      result = await this.#apiFunction(args);

      // A page only tells us about its own direction; the server leaves the
      // other flag null.
      if (args.direction === FUTURE) {
        this.canLoadMoreFuture = result.meta.can_load_more_future;
      } else if (args.direction === PAST) {
        this.canLoadMorePast = result.meta.can_load_more_past;
      }

      this.#extendFetchedWindow(result.messages, args.direction);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }

    return result;
  }

  async load(args = {}) {
    this.canLoadMorePast = true;
    this.canLoadMoreFuture = true;
    this.fetchedOnce = false;
    this.loading = true;
    this.#oldestFetchedMessageId = null;
    this.#newestFetchedMessageId = null;

    args.page_size ??= DEFAULT_MESSAGE_PAGE_SIZE;

    args = this.#cleanArgs(args);

    let result;
    try {
      result = await this.#apiFunction(args);
      this.canLoadMoreFuture = result.meta.can_load_more_future;
      this.canLoadMorePast = result.meta.can_load_more_past;
      this.#extendFetchedWindow(result.messages);
      this.fetchedOnce = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }

    return result;
  }

  #apiFunction(args = {}) {
    if (this.model instanceof ChatChannel) {
      return this.chatApi.channelMessages(this.model.id, args);
    } else {
      return this.chatApi.channelThreadMessages(
        this.model.channel.id,
        this.model.id,
        args
      );
    }
  }

  #cleanArgs(args) {
    return Object.keys(args)
      .filter((k) => args[k] != null)
      .reduce((a, k) => ({ ...a, [k]: args[k] }), {});
  }

  // Pages arrive oldest-first in both directions.
  #extendFetchedWindow(messages = [], direction) {
    if (!messages.length) {
      return;
    }

    if (direction !== FUTURE) {
      this.#oldestFetchedMessageId = messages[0].id;
    }

    if (direction !== PAST) {
      this.#newestFetchedMessageId = messages.at(-1).id;
    }
  }
}
