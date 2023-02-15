import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelThread extends DiscourseRoute {
  @service router;
  @service chatStateManager;
  @service chat;

  async model(params) {
    return this.chat.activeChannel.threadsManager.find(
      this.modelFor("chat.channel").id,
      params.threadId
    );
  }

  afterModel(model) {
    this.chat.activeChannel.activeThread = model;
    this.chatStateManager.openSidePanel();
  }
}
