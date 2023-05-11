import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
export default class ChatChannelThreads extends DiscourseRoute {
  @service router;
  @service chatChannelThreadListPane;

  beforeModel(transition) {
    const channel = this.modelFor("chat.channel");

    if (!channel.threadingEnabled) {
      transition.abort();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
      return;
    }
  }

  @action
  willTransition() {
    this.chatChannelThreadListPane.close();
  }

  activate() {
    this.chatChannelThreadListPane.open();
  }
}
