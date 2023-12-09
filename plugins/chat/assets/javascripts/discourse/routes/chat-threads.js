import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelThreads extends DiscourseRoute {
  @service chat;

  activate() {
    this.chat.activeChannel = null;
  }
}
