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
          .then(() => {
            next(() => {
              message.thread = thread;

              console.log(message.thread);
              this.chatChannelThreadComposer.replyTo(message);
            });
          });
      }
    } else {
      console.log("nothread");
      this.message.inReplyTo = message;
    }
  }
}
