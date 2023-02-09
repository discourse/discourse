import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelThread extends DiscourseRoute {
  @service router;
  @service chatThreadsManager;
  @service chatStateManager;
  @service chat;

  async model(params) {
    return this.chatThreadsManager.find(
      this.chat.activeChannel.id,
      params.threadId
    );
  }

  afterModel(model) {
    this.chat.activeThread = model;
    this.chatStateManager.openSidePanel();
  }
}
