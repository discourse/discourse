import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import withChatChannel from "./chat-channel-decorator";

@withChatChannel
export default class ChatChannelRoute extends DiscourseRoute {
  @service chatStateManager;

  @action
  willTransition(transition) {
    if (transition.targetName === "chat.channel.thread") {
      this.chatStateManager.openedThreadFrom = "channel";
    }
  }
}
