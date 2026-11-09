import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoIndexRoute extends DiscourseRoute {
  @service router;

  afterModel(model) {
    if (model.isOpen && model.currentUserMembership.following) {
      this.router.replaceWith("chat.channel.info.preferences");
    } else {
      this.router.replaceWith("chat.channel.info.settings");
    }
  }
}
