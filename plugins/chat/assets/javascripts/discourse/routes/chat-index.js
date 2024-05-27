import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatIndexRoute extends DiscourseRoute {
  @service chat;
  @service chatChannelsManager;
  @service router;
  @service siteSettings;
  @service currentUser;

  get hasThreads() {
    if (!this.siteSettings.chat_threads_enabled) {
      return false;
    }

    return this.chatChannelsManager.hasThreadedChannels;
  }

  get hasDirectMessages() {
    return this.chat.userCanAccessDirectMessages;
  }

  activate() {
    this.chat.activeChannel = null;
  }

  async model() {
    return await this.chat.loadChannels();
  }

  async redirect() {
    // on mobile redirect user to the first footer tab route
    if (this.site.mobileView) {
      if (
        this.siteSettings.chat_preferred_mobile_index === "my_threads" &&
        this.hasThreads
      ) {
        return this.router.replaceWith("chat.threads");
      } else if (
        this.siteSettings.chat_preferred_mobile_index === "direct_messages" &&
        this.hasDirectMessages
      ) {
        return this.router.replaceWith("chat.direct-messages");
      } else {
        return this.router.replaceWith("chat.channels");
      }
    }

    // We are on desktop. Check for last visited channel and transition if so
    const id = this.currentUser.custom_fields.last_chat_channel_id;
    if (id) {
      return this.chatChannelsManager.find(id).then((c) => {
        return this.router.replaceWith("chat.channel", ...c.routeModels);
      });
    } else {
      return this.router.replaceWith("chat.browse");
    }
  }
}
