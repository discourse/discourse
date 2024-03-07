import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ORIGINS } from "discourse/plugins/chat/discourse/services/chat-channel-info-route-origin-manager";
import withChatChannel from "./chat-channel-decorator";

@withChatChannel
export default class ChatChannelInfoRoute extends DiscourseRoute {
  @service chatChannelInfoRouteOriginManager;

  activate(transition) {
    const name = transition?.from?.name;
    if (name) {
      this.chatChannelInfoRouteOriginManager.origin = name.startsWith(
        "chat.browse"
      )
        ? ORIGINS.browse
        : ORIGINS.channel;
    }
  }

  deactivate() {
    this.chatChannelInfoRouteOriginManager.origin = null;
  }
}
