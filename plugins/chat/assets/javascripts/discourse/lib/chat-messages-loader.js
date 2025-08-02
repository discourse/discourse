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

    const nextTargetMessage = this.#computeNextTargetMessage(
      args.direction,
      this.model
    );

    args = {
      direction: args.direction,
      page_size: DEFAULT_MESSAGE_PAGE_SIZE,
      target_message_id: nextTargetMessage?.id,
    };

    args = this.#cleanArgs(args);

    let result;
    try {
      this.loading = true;
      result = await this.#apiFunction(args);
      this.canLoadMoreFuture = result.meta.can_load_more_future;
      this.canLoadMorePast = result.meta.can_load_more_past;
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

    args.page_size ??= DEFAULT_MESSAGE_PAGE_SIZE;

    args = this.#cleanArgs(args);

    let result;
    try {
      result = await this.#apiFunction(args);
      this.canLoadMoreFuture = result.meta.can_load_more_future;
      this.canLoadMorePast = result.meta.can_load_more_past;
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

  #computeNextTargetMessage(direction, model) {
    return direction === PAST
      ? model.messagesManager.messages.find((message) => !message.staged)
      : model.messagesManager.messages.findLast((message) => !message.staged);
  }
}
