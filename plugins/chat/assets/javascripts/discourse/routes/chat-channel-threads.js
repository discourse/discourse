import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatChannelThreads extends DiscourseRoute {
  @service router;
  @service chatThreadListPane;
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
    if (
      transition.targetName === "chat.channel.index" ||
      transition.targetName === "chat.channel.near-message" ||
      transition.targetName === "chat.index" ||
      !transition.targetName.startsWith("chat")
    ) {
      this.chatStateManager.closeSidePanel();
    }
  }
}
