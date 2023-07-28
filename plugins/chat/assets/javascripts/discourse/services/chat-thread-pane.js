import ChatChannelPane from "./chat-channel-pane";
import { inject as service } from "@ember/service";

export default class ChatThreadPane extends ChatChannelPane {
  @service chat;
  @service router;

  get thread() {
    return this.channel?.activeThread;
  }

  get isOpened() {
    return this.router.currentRoute.name === "chat.channel.thread";
  }

  get selectedMessageIds() {
    return this.thread.messagesManager.selectedMessages.mapBy("id");
  }

  async close() {
    await this.router.transitionTo("chat.channel", ...this.channel.routeModels);
  }

  async open(thread) {
    await this.router.transitionTo(
      "chat.channel.thread",
      ...thread.routeModels
    );
  }
}
