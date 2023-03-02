import DiscourseRoute from "discourse/routes/discourse";
import withChatChannel from "./chat-channel-decorator";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

@withChatChannel
export default class ChatChannelRoute extends DiscourseRoute {
  @service chat;
  @service chatStateManager;

  @action
  willTransition(transition) {
    // Technically we could keep messages to avoid re-fetching them, but
    // it's not worth the complexity for now
    this.chat.activeChannel?.clearMessages();

    this.chat.activeChannel.activeThread = null;
    this.chatStateManager.closeSidePanel();

    if (!transition?.to?.name?.startsWith("chat.")) {
      this.chatStateManager.storeChatURL();
      this.chat.activeChannel = null;
      this.chat.updatePresence();
    }
  }
}
