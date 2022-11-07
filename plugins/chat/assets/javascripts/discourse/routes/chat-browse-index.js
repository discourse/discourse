import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatBrowseIndexRoute extends DiscourseRoute {
  @service chat;

  activate() {
    this.chat.setActiveChannel(null);
  }

  afterModel() {
    this.replaceWith("chat.browse.open");
  }
}
