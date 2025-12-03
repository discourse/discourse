import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatStarredChannelsRoute extends DiscourseRoute {
  @service chat;
  @service chatStateManager;
  @service router;
  @service site;

  activate() {
    this.chat.activeChannel = null;
  }

  async beforeModel() {
    // Redirect on desktop - mobile-only feature
    if (!this.site.mobileView) {
      const channel = this.chat.activeChannel;
      const lastKnownURL = this.chatStateManager.lastKnownChatURL;

      if (channel) {
        this.router.replaceWith("chat.channel", ...channel.routeModels);
      } else if (lastKnownURL) {
        this.router.replaceWith(lastKnownURL);
      } else {
        this.router.replaceWith("chat");
      }
      return;
    }

    // Load channels before rendering
    await this.chat.loadChannels();
  }
}
