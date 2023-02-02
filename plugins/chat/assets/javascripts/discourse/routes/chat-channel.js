import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelRoute extends DiscourseRoute {
  @service chatChannelsManager;
  @service chat;
  @service router;

  async model(params) {
    return this.chatChannelsManager.find(params.channelId);
  }

  afterModel(model) {
    this.chat.setActiveChannel(model);

    const { messageId } = this.paramsFor(this.routeName);

    // messageId query param backwards-compatibility
    if (messageId) {
      this.router.replaceWith(
        "chat.channel.near-message",
        ...model.routeModels,
        messageId
      );
    }
  }
}
