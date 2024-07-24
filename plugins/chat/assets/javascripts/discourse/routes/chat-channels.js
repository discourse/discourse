import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelsRoute extends DiscourseRoute {
  @service chat;
  @service chatChannelsManager;

  activate() {
    this.chat.activeChannel = null;
  }

  beforeModel() {
    const id = this.currentUser.custom_fields.last_chat_channel_id;
    if (id && this.site.desktopView) {
      this.chatChannelsManager.find(id).then((c) => {
        return this.router.replaceWith("chat.channel", ...c.routeModels);
      });
    }
  }

  model() {
    return this.chatChannelsManager.publicMessageChannels;
  }
}
