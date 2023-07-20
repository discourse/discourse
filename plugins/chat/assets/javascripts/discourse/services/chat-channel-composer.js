import Service, { inject as service } from "@ember/service";
import { action } from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { tracked } from "@glimmer/tracking";

export default class ChatChannelComposer extends Service {
  @service chat;
  @service currentUser;
  @service router;
  @service siteSettings;
  @service("chat-thread-composer") threadComposer;

  @tracked message;
  @tracked textarea;

  @action
  focus(options = {}) {
    this.textarea?.focus(options);
  }

  @action
  blur() {
    this.textarea.blur();
  }

  @action
  reset(channel) {
    this.message = ChatMessage.createDraftMessage(channel, {
      user: this.currentUser,
    });
  }

  @action
  cancel() {
    if (this.message.editing) {
      this.reset(this.message.channel);
    } else if (this.message.inReplyTo) {
      this.message.inReplyTo = null;
    }

    this.focus({ ensureAtEnd: true, refreshHeight: true });
  }

  @action
  edit(message) {
    this.chat.activeMessage = null;
    message.editing = true;
    this.message = message;
    this.focus({ refreshHeight: true, ensureAtEnd: true });
  }

  @action
  async replyTo(message) {
    this.chat.activeMessage = null;

    if (
      this.siteSettings.enable_experimental_chat_threaded_discussions &&
      message.channel.threadingEnabled
    ) {
      if (!message.thread?.id) {
        message.thread = message.channel.createStagedThread(message);
      }

      this.reset(message.channel);

      await this.router.transitionTo(
        "chat.channel.thread",
        ...message.thread.routeModels
      );

      this.threadComposer.focus({ ensureAtEnd: true, refreshHeight: true });
    } else {
      this.message.inReplyTo = message;
      this.focus({ ensureAtEnd: true, refreshHeight: true });
    }
  }
}
