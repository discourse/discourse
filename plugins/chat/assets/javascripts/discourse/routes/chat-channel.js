import DiscourseRoute from "discourse/routes/discourse";
import withChatChannel from "./chat-channel-decorator";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

@withChatChannel
export default class ChatChannelRoute extends DiscourseRoute {
  @service chatThreadsManager;
  @service chatStateManager;

  @action
  willTransition() {
    this.chatStateManager.closeSidePanel();
  }

  beforeModel() {
    this.chatThreadsManager.resetCache();
  }
}
