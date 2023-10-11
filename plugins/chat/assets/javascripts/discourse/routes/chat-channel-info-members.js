import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoMembersRoute extends DiscourseRoute {
  @service router;

  afterModel(model) {
    if (!model.isOpen || model.membershipsCount < 1) {
      return this.router.replaceWith("chat.channel.info.settings");
    }
  }
}
