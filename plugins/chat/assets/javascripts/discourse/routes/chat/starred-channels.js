import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatStarredChannelsRoute extends DiscourseRoute {
  @service chat;
  @service chatChannelsManager;
  @service router;
  @service site;

  activate() {
    this.chat.activeChannel = null;
  }

  async beforeModel() {
    if (this.site.desktopView) {
      const channel = this.chat.activeChannel;

      if (channel) {
        this.router.replaceWith("chat.channel", ...channel.routeModels);
      } else {
        this.router.replaceWith("chat");
      }
    } else {
      // Load channels before rendering (mobile only)
      await this.chat.loadChannels();

      // If there are no starred channels, redirect to all channels
      if (!this.chatChannelsManager.hasStarredChannels) {
        this.router.replaceWith("chat.channels");
      }
    }
  }
}
