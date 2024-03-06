import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoIndexRoute extends DiscourseRoute {
  @service router;

  afterModel() {
    this.router.replaceWith("chat.channel.info.settings");
  }
}
