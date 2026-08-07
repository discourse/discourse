import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelThreads extends DiscourseRoute {
  @service chat;
  @service chatStateManager;
  @service currentUser;
  @service router;

  beforeModel() {
    if (!this.currentUser) {
      return this.router.replaceWith("chat.channels");
    }
  }

  activate() {
    this.chat.activeChannel = null;
    this.chatStateManager.closeSidePanel();
  }
}
