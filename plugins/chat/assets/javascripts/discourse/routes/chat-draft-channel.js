import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatDraftChannelRoute extends DiscourseRoute {
  @service chat;

  beforeModel() {
    if (!this.chat.userCanDirectMessage) {
      this.transitionTo("chat");
    }
  }

  activate() {
    this.chat.activeChannel = null;
  }
}
