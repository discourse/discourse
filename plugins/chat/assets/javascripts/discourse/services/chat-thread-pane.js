import ChatChannelPane from "./chat-channel-pane";
import { inject as service } from "@ember/service";

export default class ChatThreadPane extends ChatChannelPane {
  @service chat;
  @service router;

  get isOpened() {
    return this.router.currentRoute.name === "chat.channel.thread";
  }

  async close() {
    await this.router.transitionTo(
      "chat.channel",
      ...this.chat.activeChannel.routeModels
    );
  }

  async open(thread) {
    await this.router.transitionTo(
      "chat.channel.thread",
      ...thread.routeModels
    );
  }

  get selectedMessageIds() {
    return this.chat.activeChannel.activeThread.selectedMessages.mapBy("id");
  }
}
