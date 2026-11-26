import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatComposerService from "discourse/plugins/chat/discourse/lib/chat-composer-service";

export default class ChatChannelComposer extends ChatComposerService {
  @service chat;
  @service chatApi;
  @service currentUser;
  @service router;
  @service("chat-thread-composer") threadComposer;
  @service loadingSlider;
  @service site;

  @action
  edit(message) {
    this.chat.activeMessage = null;
    message.editing = true;
    message.channel.draft = message;

    if (this.site.desktopView) {
      this.focus({ ensureAtEnd: true });
    }
  }

  @action
  async replyTo(message) {
    this.chat.activeMessage = null;

    if (message.channel.threadingEnabled) {
      if (!message.thread) {
        try {
          this.loadingSlider.transitionStarted();
          message.thread = await this.#resolveThread(message);
        } finally {
          this.loadingSlider.transitionEnded();
        }
      }

      message.channel.resetDraft(this.currentUser);

      try {
        await this.router.transitionTo(
          "chat.channel.thread",
          ...message.thread.routeModels
        );
      } catch (e) {
        if (e.name !== "TransitionAborted") {
          throw e;
        }
      }

      this.threadComposer.focus({ ensureAtEnd: true });
    } else {
      message.channel.draft.inReplyTo = message;
      this.focus({ ensureAtEnd: true });
    }
  }

  async #resolveThread(message) {
    if (message.threadId) {
      return message.channel.threadsManager.find(
        message.channel.id,
        message.threadId
      );
    }

    const threadObject = await this.chatApi.createThread(
      message.channel.id,
      message.id
    );
    return message.channel.threadsManager.add(message.channel, threadObject);
  }
}
