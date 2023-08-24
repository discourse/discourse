import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelInfoMembersRoute extends DiscourseRoute {
  @service router;

  afterModel(model) {
    if (!model.isOpen) {
      return this.router.replaceWith("chat.channel.info.settings");
    }

    if (model.membershipsCount < 1) {
      return this.router.replaceWith("chat.channel.info");
    }
  }
}
