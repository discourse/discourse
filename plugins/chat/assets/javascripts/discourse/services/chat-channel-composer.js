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
      if (message.thread?.id) {
        this.router.transitionTo(
          "chat.channel.thread",
          ...[...channel.routeModels, message.thread.id]
        );
      } else {
        const thread = channel.createStagedThread(message);

        this.router
          .transitionTo(
            "chat.channel.thread",
            ...[...channel.routeModels, thread.id]
          )
          .catch((e) => {
            // drawer aborts the transition for the custom router handling
            if (e.message === "TransitionAborted") {
              this._setReplyToAfterTransition(message, thread);
            }
          })
          .then(() => this._setReplyToAfterTransition(message, thread));
      }
    } else {
      this.message.inReplyTo = message;
    }
  }

  _setReplyToAfterTransition(message, thread) {
    next(() => {
      message.thread = thread;
      this.chatChannelThreadComposer.replyTo(message);
    });
  }
}
