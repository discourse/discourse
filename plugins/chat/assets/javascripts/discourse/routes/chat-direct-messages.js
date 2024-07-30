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
      } else {
        // there should be at least one dm channel
        // we can reroute using the last channel id
        const id = this.currentUser.custom_fields.last_chat_channel_id;
        this.chatChannelsManager.find(id).then((c) => {
          return this.router.replaceWith("chat.channel", ...c.routeModels);
        });
      }
    }
  }

  model() {
    return this.chatChannelsManager.directMessageChannels;
  }
}
