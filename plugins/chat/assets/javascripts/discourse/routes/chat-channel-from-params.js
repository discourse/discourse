import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelFromParamsRoute extends DiscourseRoute {
  @service router;

  async model() {
    return this.modelFor("chat-channel");
  }

  afterModel(model) {
    const { channelTitle } = this.paramsFor("chat.channel");

    if (channelTitle !== model.slugifiedTitle) {
      this.router.replaceWith("chat.channel.from-params", ...model.routeModels);
    }
  }
}
