import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";

export default class ChatChannelRoute extends DiscourseRoute {
  @service chat;
  @service router;
  @service chatChannelsManager;

  async model(params) {
    return this.chatChannelsManager.find(params.channelId);
  }

  afterModel(model) {
    this.chat.setActiveChannel(model);

    const { channelTitle, messageId } = this.paramsFor(this.routeName);
    const slug = slugifyChannel(model);
    if (channelTitle !== slug) {
      this.router.replaceWith("chat.channel.index", model.id, slug, {
        queryParams: { messageId },
      });
    }
  }

  @action
  didTransition() {
    const { channelId, messageId } = this.paramsFor(this.routeName);
    if (channelId && messageId) {
      schedule("afterRender", () => {
        this.chat.openChannelAtMessage(channelId, messageId);
        this.controller.set("messageId", null); // clear the query param
      });
    }
    return true;
  }
}
