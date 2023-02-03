import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";

export default class ChatChannelThread extends DiscourseRoute {
  @service chatChannelsManager;
  @service chat;
  @service router;

  async model(params) {
    return this.chatChannelsManager.findThread(params.threadId);
  }

  afterModel(model) {
    this.chat.setActiveThread(model);
  }

  @action
  didTransition() {
    const { channelId } = this.paramsFor("chat.channel");
    const { threadId } = this.paramsFor(this.routeName);

    if (channelId && threadId) {
      schedule("afterRender", () => {
        this.chat.openThreadSidebar(channelId, threadId);
      });
    }
    return true;
  }
}
