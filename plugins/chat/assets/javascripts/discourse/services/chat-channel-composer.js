import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";

export default class ChatChannelComposer extends Service {
  @service chat;
  @service chatApi;
  @service currentUser;
  @service router;
  @service("chat-thread-composer") threadComposer;
  @service loadingSlider;

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
  edit(message) {
    this.chat.activeMessage = null;
    message.editing = true;
    message.channel.draft = message;
    this.focus({ refreshHeight: true, ensureAtEnd: true });
  }

  @action
  async replyTo(message) {
    this.chat.activeMessage = null;

    if (message.channel.threadingEnabled) {
      if (!message.thread?.id) {
        try {
          this.loadingSlider.transitionStarted();
          const threadObject = await this.chatApi.createThread(
            message.channel.id,
            message.id
          );
          message.thread = message.channel.threadsManager.add(
            message.channel,
            threadObject
          );
        } finally {
          this.loadingSlider.transitionEnded();
        }
      }

      message.channel.resetDraft(this.currentUser);

      await this.router.transitionTo(
        "chat.channel.thread",
        ...message.thread.routeModels
      );

      this.threadComposer.focus({ ensureAtEnd: true, refreshHeight: true });
    } else {
      message.channel.draft.inReplyTo = message;
      this.focus({ ensureAtEnd: true, refreshHeight: true });
    }
  }
}
