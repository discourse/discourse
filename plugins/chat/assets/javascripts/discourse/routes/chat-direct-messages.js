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
      this.router.transitionTo("chat");
    }
  }

  model() {
    return this.chatChannelsManager.directMessageChannels;
  }
}
