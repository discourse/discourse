import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelThread extends DiscourseRoute {
  @service router;
  @service chatThreadsManager;
  @service chat;

  async model(params) {
    return this.chatThreadsManager.find(params.threadId);
  }

  afterModel(model) {
    this.chat.setActiveThread(model);
  }
}
