import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";

export default class ChatChannelRoute extends DiscourseRoute {
  @service chat;
  @service router;
  @service chatChannelsManager;

  async model(params) {
    return this.chatChannelsManager.find(params.channelId);
  }

  afterModel(model, transition) {
    this.chat.setActiveChannel(model);

    const { channelTitle, messageId } = this.paramsFor(this.routeName);

    // Backwards-compatibility
    if (messageId) {
      this.router.replaceWith(
        "chat.channel.near-message",
        channelTitle,
        model.id,
        messageId
      );
      this.controller("messageId", null);
    }

    // Rewrite URL with slug in the child route to preseve
    // the :messageId dynamic segment when highlighting a specific message.
    if (transition.to.name !== "chat.channel.near-message") {
      const slug = slugifyChannel(model);
      if (channelTitle !== model.slugifiedTitle) {
        this.router.replaceWith("chat.channel.index", ...model.routeModels);
      }
    }
  }
}
