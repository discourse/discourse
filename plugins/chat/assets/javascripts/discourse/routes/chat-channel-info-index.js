import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelInfoIndexRoute extends DiscourseRoute {
  @service router;

  afterModel(model) {
    if (model.isDirectMessageChannel) {
      if (model.isOpen && model.membershipsCount >= 1) {
        this.router.replaceWith("chat.channel.info.members");
      } else {
        this.router.replaceWith("chat.channel.info.settings");
      }
    } else {
      this.router.replaceWith("chat.channel.info.about");
    }
  }
}
