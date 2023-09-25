import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelInfoAboutRoute extends DiscourseRoute {
  @service router;

  afterModel(model) {
    if (model.isDirectMessageChannel) {
      this.router.replaceWith("chat.channel.info.index");
    }
  }
}
