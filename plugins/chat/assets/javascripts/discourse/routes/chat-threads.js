import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelThreads extends DiscourseRoute {
  @service chat;
  @service chatStateManager;

  activate() {
    this.chat.activeChannel = null;
    this.chatStateManager.closeSidePanel();
  }
}
