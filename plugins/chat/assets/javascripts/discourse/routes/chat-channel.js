import DiscourseRoute from "discourse/routes/discourse";
import withChatChannel from "./chat-channel-decorator";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

@withChatChannel
export default class ChatChannelRoute extends DiscourseRoute {
  @service chat;
  @service chatStateManager;

  afterModel() {
    super.afterModel?.(...arguments);

    // Clear messages of the previous channel
    this.chat.activeChannel?.clearMessages();
  }

  @action
  willTransition() {
    this.#closeThread();
  }

  @action
  didTransition() {
    this.chatStateManager.storeChatURL();
  }

  @action
  deactivate() {
    this.chat.activeChannel = null;
  }

  #closeThread() {
    this.chat.activeChannel.activeThread?.messagesManager?.clearMessages();
    this.chat.activeChannel.activeThread = null;
    this.chatStateManager.closeSidePanel();
  }
}
