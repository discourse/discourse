import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoPreferencesRoute extends DiscourseRoute {
  @service router;

  afterModel(model) {
    if (!model.isOpen || !model.currentUserMembership.following) {
      return this.router.replaceWith("chat.channel.info.settings");
    }
  }
}
