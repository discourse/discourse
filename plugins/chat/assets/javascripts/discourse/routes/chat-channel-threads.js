import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelThreads extends DiscourseRoute {
  @service router;
  @service chatThreadListPane;
  @service chatStateManager;
  @service chat;

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
  activate() {
    this.chat.activeMessage = null;
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
