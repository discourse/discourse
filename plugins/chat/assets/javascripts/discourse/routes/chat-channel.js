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
    this.chat.activeChannel.activeThread = null;
    this.chatStateManager.closeSidePanel();

    if (transition?.to?.name === "chat.channel.index") {
      const targetChannelId = transition?.to?.parent?.params?.channelId;
      if (
        targetChannelId &&
        parseInt(targetChannelId, 10) !== this.chat.activeChannel.id
      ) {
        this.chat.activeChannel.clearMessages();
      }
    }

    if (!transition?.to?.name?.startsWith("chat.")) {
      this.chatStateManager.storeChatURL();
      this.chat.activeChannel = null;
      this.chat.updatePresence();
    }
  }
}
