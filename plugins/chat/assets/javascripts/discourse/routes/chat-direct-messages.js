import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatDirectMessagesRoute extends DiscourseRoute {
  @service chat;
  @service chatChannelsManager;

  activate() {
    this.chat.activeChannel = null;
  }

  model() {
    if (this.site.desktopView) {
      return this.router.replaceWith("chat");
    }

    return this.chatChannelsManager.directMessageChannels;
  }
}
