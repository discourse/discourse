import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelInfoIndexRoute extends DiscourseRoute {
  @service router;

  afterModel() {
    this.router.replaceWith("chat.channel.info.settings");
  }
}
