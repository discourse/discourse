import DiscourseRoute from "discourse/routes/discourse";
import withChatChannel from "./chat-channel-decorator";
import { inject as service } from "@ember/service";

@withChatChannel
export default class ChatChannelRoute extends DiscourseRoute {
  @service chat;
  @service chatStateManager;

  beforeModel() {
    if (this.chat.activeChannel) {
      // When moving between channels
      this.#closeThread();
    }
  }

  deactivate() {
    this.#closeThread();
  }

  #closeThread() {
    this.chat.activeChannel.activeThread?.messagesManager?.clearMessages();
    this.chat.activeChannel.activeThread = null;
    this.chatStateManager.closeSidePanel();
  }
}
