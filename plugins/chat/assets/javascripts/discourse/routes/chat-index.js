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
    if (
      this.siteSettings.chat_preferred_index === "my_threads" &&
      this.hasThreads
    ) {
      return this.router.replaceWith("chat.threads");
    } else if (
      this.siteSettings.chat_preferred_index === "direct_messages" &&
      this.hasDirectMessages
    ) {
      return this.router.replaceWith("chat.direct-messages");
    } else {
      return this.router.replaceWith("chat.channels");
    }
  }
}
