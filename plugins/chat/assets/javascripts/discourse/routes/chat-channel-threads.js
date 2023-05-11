import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelThreads extends DiscourseRoute {
  @service router;
  @service chatChannelThreadListPane;

  deactivate() {
    this.chatChannelThreadListPane.close();
  }

  beforeModel(transition) {
    const channel = this.modelFor("chat.channel");

    if (!channel.threadingEnabled) {
      transition.abort();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
      return;
    }
  }

  activate() {
    this.chatChannelThreadListPane.open();
  }
}
