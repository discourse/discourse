import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatStarredChannelsRoute extends DiscourseRoute {
  @service chat;
  @service router;
  @service site;

  activate() {
    this.chat.activeChannel = null;
  }

  async beforeModel() {
    // Redirect on desktop fullscreen - starred channels are shown in sidebar
    if (!this.site.mobileView) {
      const channel = this.chat.activeChannel;

      if (channel) {
        this.router.replaceWith("chat.channel", ...channel.routeModels);
      } else {
        this.router.replaceWith("chat");
      }
      return;
    }

    // Load channels before rendering (mobile only)
    await this.chat.loadChannels();
  }
}
