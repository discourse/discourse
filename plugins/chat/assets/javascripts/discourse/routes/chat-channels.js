import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelsRoute extends DiscourseRoute {
  @service chat;
  @service chatChannelsManager;
  @service siteSettings;

  activate() {
    this.chat.activeChannel = null;
  }

  beforeModel() {
    const id = this.currentUser.custom_fields.last_chat_channel_id;
    if (this.site.desktopView) {
      if (id) {
        this.chatChannelsManager.find(id).then((c) => {
          return this.router.replaceWith("chat.channel", ...c.routeModels);
        });
      } else {
        this.router.replaceWith("chat.browse.open");
      }
    }
  }

  model() {
    return this.chatChannelsManager.publicMessageChannels;
  }
}
