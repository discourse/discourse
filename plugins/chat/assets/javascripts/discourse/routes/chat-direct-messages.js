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
      const id = this.currentUser.custom_fields.last_chat_channel_id;
      if (id) {
        return this.chatChannelsManager.find(id).then((c) => {
          return this.router.replaceWith("chat.channel", ...c.routeModels);
        });
      }
      // first time browsing chat and the preferred index is dms
      // if no dm, redirect to browse
      return this.router.replaceWith("chat.browse.open");
    }
  }

  model() {
    return this.chatChannelsManager.directMessageChannels;
  }
}
