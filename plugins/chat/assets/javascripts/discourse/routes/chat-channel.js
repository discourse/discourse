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

  afterModel(model) {
    this.chat.setActiveChannel(model);

    const queryParams = this.paramsFor(this.routeName);
    const slug = slugifyChannel(model);
    if (queryParams?.channelTitle !== slug) {
      this.router.replaceWith("chat.channel.index", model.id, slug);
    }
  }

  setupController(controller) {
    super.setupController(...arguments);

    if (controller.messageId) {
      this.chat.set("messageId", controller.messageId);
      this.controller.set("messageId", null);
    }
  }
}
