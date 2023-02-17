import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelThread extends DiscourseRoute {
  @service router;
  @service chatStateManager;
  @service chat;

  async model(params) {
    const channel = this.modelFor("chat.channel");
    return channel.threadsManager.find(channel.id, params.threadId);
  }

  afterModel(model) {
    this.chat.activeChannel.activeThread = model;
    this.chatStateManager.openSidePanel();
  }
}
