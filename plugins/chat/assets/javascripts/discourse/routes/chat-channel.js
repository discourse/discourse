import DiscourseRoute from "discourse/routes/discourse";
import withChatChannel from "./chat-channel-decorator";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

@withChatChannel
export default class ChatChannelRoute extends DiscourseRoute {
  @service chatThreadsManager;
  @service chatStateManager;

  @action
  willTransition(transition) {
    this.chat.activeThread = null;
    this.chatStateManager.closeSidePanel();

    if (!transition?.to?.name?.startsWith("chat.")) {
      this.chatStateManager.storeChatURL();
      this.chat.activeChannel = null;
      this.chat.updatePresence();
    }
  }

  beforeModel() {
    this.chatThreadsManager.resetCache();
  }
}
