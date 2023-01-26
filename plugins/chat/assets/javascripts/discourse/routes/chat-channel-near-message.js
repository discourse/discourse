import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";

export default class ChatNearMessageRoute extends DiscourseRoute {
  @service chat;
  @service router;

  async model() {
    return this.modelFor("chat-channel");
  }

  afterModel(model) {
    const { messageId } = this.paramsFor(this.routeName);
    const { channelTitle } = this.paramsFor("chat.channel");

    if (channelTitle !== model.slugifiedTitle) {
      this.router.replaceWith(
        "chat.channel.near-message",
        ...model.routeModels,
        messageId
      );
    }
  }

  @action
  didTransition() {
    const { messageId } = this.paramsFor(this.routeName);
    const { channelId } = this.paramsFor("chat.channel");

    if (channelId && messageId) {
      schedule("afterRender", () => {
        this.chat.openChannelAtMessage(channelId, messageId);
      });
    }
    return true;
  }
}
