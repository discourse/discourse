import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatChannelThreads extends DiscourseRoute {
  @service router;
  @service chatChannelThreadListPane;
  @service chatStateManager;

  beforeModel(transition) {
    const channel = this.modelFor("chat.channel");

    if (!channel.threadingEnabled) {
      transition.abort();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
      return;
    }

    this.chatStateManager.openSidePanel();
  }

  @action
  willTransition(transition) {
    if (transition.targetName !== "chat.channel.thread") {
      this.chatChannelThreadListPane.close();
    }
  }

  activate() {
    this.chatChannelThreadListPane.open();
  }
}
