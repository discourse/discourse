import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelsRoute extends DiscourseRoute {
  @service chat;
  @service chatChannelsManager;

  activate() {
    this.chat.activeChannel = null;
  }

  model() {
    return this.chatChannelsManager.publicMessageChannels;
  }
}
