import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatDraftChannelRoute extends DiscourseRoute {
  @service chat;
  @service router;

  beforeModel() {
    if (!this.chat.userCanDirectMessage) {
      this.router.transitionTo("chat");
    }
  }

  activate() {
    this.chat.activeChannel = null;
  }
}
