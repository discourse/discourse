import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelsRoute extends DiscourseRoute {
  @service chat;
  @service chatChannelsManager;
  @service router;

  activate() {
    this.chat.activeChannel = null;
  }

  async beforeModel() {
    if (!this.site.desktopView) {
      return;
    }

    const id = this.currentUser.custom_fields.last_chat_channel_id;
    if (id) {
      const channel = await this.chatChannelsManager.find(id);
      if (
        channel?.isCategoryChannel &&
        channel.currentUserMembership?.following
      ) {
        return this.router.replaceWith("chat.channel", ...channel.routeModels);
      }
    }

    return this.router.replaceWith("chat.browse.open");
  }

  model() {
    return this.chatChannelsManager.publicMessageChannels;
  }
}
