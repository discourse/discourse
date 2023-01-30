import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

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
        ...model.routeModels,
        messageId
      );
      this.controller.set("messageId", null);
    }

    // Rewrite URL with slug in the child route to preseve
    // the :messageId dynamic segment when highlighting a specific message.
    if (transition.to.name !== "chat.channel.near-message") {
      if (channelTitle !== model.slugifiedTitle) {
        this.router.replaceWith("chat.channel.index", ...model.routeModels);
      }
    }
  }
}
