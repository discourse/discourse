import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import ChatComposer from "./chat-composer";

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

      this.chat.activeMessage = null;
      this.router.transitionTo("chat.channel.thread", ...thread.routeModels);
    } else {
      this.message.inReplyTo = message;
    }
  }
}
