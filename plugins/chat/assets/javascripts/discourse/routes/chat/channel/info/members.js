import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoMembersRoute extends DiscourseRoute {
  @service router;

  afterModel(model) {
    if (!model.isOpen) {
      return this.router.replaceWith("chat.channel.info.settings");
    }
  }
}
