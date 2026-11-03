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
  // because it also holds messages that never came from a page.
  #oldestFetchedMessageId = null;
  #newestFetchedMessageId = null;
  #newestLiveMessageId = null;

  constructor(owner, model) {
    setOwner(this, owner);
    this.model = model;
  }

  get loadedPast() {
    return this.canLoadMorePast === false && this.fetchedOnce;
  }

  /**
   * Records a message received live while newer history is still unloaded, so
   * a page that reaches the end of the stream without it is followed by one more.
   *
   * @param {ChatMessage} message
   */
  trackLiveMessage(message) {
    if (!this.canLoadMoreFuture || message.staged) {
      return;
    }

    if (message.id > (this.#newestLiveMessageId ?? 0)) {
      this.#newestLiveMessageId = message.id;
    }
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

      if (args.direction === FUTURE) {
        result = await this.#catchUpWithLiveMessages(result);
      }
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
      result = await this.#catchUpWithLiveMessages(result);
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

  // A message can be posted after the server built the last page but reach us
  // before it, while it is held back as pending. One more page picks it up; only
  // one, since a message deleted meanwhile will never arrive.
  async #catchUpWithLiveMessages(result) {
    if (
      this.canLoadMoreFuture ||
      !(this.#newestLiveMessageId > (this.#newestFetchedMessageId ?? 0))
    ) {
      return result;
    }

    this.#newestLiveMessageId = null;
    const next = await this.#apiFunction(
      this.#cleanArgs({
        direction: FUTURE,
        page_size: DEFAULT_MESSAGE_PAGE_SIZE,
        target_message_id: this.#newestFetchedMessageId,
      })
    );
    this.canLoadMoreFuture = next.meta.can_load_more_future;
    this.#extendFetchedWindow(next.messages, FUTURE);

    return { ...result, messages: [...result.messages, ...next.messages] };
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
