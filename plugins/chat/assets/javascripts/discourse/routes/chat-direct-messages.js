import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatDirectMessagesRoute extends DiscourseRoute {
  @service chat;
  @service chatChannelsManager;

  activate() {
    this.chat.activeChannel = null;
  }

  beforeModel() {
    if (this.site.desktopView) {
      if (this.chatChannelsManager.directMessageChannels.length === 0) {
        // first time browsing chat and the preferred index is dms
        this.router.replaceWith("chat.direct-messages");
      }
    }
  }

  model() {
    return this.chatChannelsManager.directMessageChannels;
  }
}
