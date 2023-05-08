import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import ChatComposer from "./chat-composer";
import { next } from "@ember/runloop";

export default class ChatChannelComposer extends ChatComposer {
  @service chat;
  @service chatChannelThreadComposer;
  @service router;

  @action
  replyTo(message) {
    this.chat.activeMessage = null;
    const channel = message.channel;

    if (
      this.siteSettings.enable_experimental_chat_threaded_discussions &&
      channel.threadingEnabled
    ) {
      let thread;
      if (message.thread?.id) {
        thread = message.thread;
      } else {
        thread = channel.createStagedThread(message);
        message.thread = thread;
      }

      this.router
        .transitionTo("chat.channel.thread", ...thread.routeModels)
        .finally(() => this._setReplyToAfterTransition(message));
    } else {
      this.message.inReplyTo = message;
    }
  }

  _setReplyToAfterTransition(message) {
    next(() => {
      this.chatChannelThreadComposer.replyTo(message);
    });
  }
}
