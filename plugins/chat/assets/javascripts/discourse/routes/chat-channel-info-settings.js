import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelInfoSettingsRoute extends DiscourseRoute {
  @service router;
  @service currentUser;

  afterModel(model) {
    if (!this.currentUser?.staff && !model.currentUserMembership?.following) {
      this.router.replaceWith("chat.channel.info");
    }
  }
}
