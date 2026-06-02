import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatDirectMessagesRoute extends DiscourseRoute {
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

    await this.chat.loadChannels();

    const dmChannels = this.chatChannelsManager.directMessageChannels;
    if (dmChannels.length === 0) {
      return;
    }

    const id = this.currentUser.custom_fields.last_chat_channel_id;
    if (id) {
      const channel = await this.chatChannelsManager.find(id);
      if (
        channel?.isDirectMessageChannel &&
        channel.currentUserMembership?.following
      ) {
        return this.router.replaceWith("chat.channel", ...channel.routeModels);
      }
    }

    return this.router.replaceWith(
      "chat.channel",
      ...dmChannels[0].routeModels
    );
  }

  model() {
    return this.chatChannelsManager.directMessageChannels;
  }
}
