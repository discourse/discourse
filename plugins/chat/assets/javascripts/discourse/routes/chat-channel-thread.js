import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatChannelThread extends DiscourseRoute {
  @service router;
  @service chatStateManager;
  @service chat;
  @service chatThreadPane;

  model(params, transition) {
    const channel = this.modelFor("chat.channel");
    return channel.threadsManager
      .find(channel.id, params.threadId)
      .catch(() => {
        transition.abort();
        this.chatStateManager.closeSidePanel();
        this.router.transitionTo("chat.channel", ...channel.routeModels);
        return;
      });
  }

  afterModel(model) {
    this.chat.activeChannel.activeThread = model;
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

  beforeModel(transition) {
    const channel = this.modelFor("chat.channel");

    if (!channel.threadingEnabled) {
      transition.abort();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
      return;
    }

    const { messageId } = this.paramsFor(this.routeName + ".near-message");
    if (
      !messageId &&
      this.controllerFor("chat-channel-thread").get("targetMessageId")
    ) {
      this.controllerFor("chat-channel-thread").set("targetMessageId", null);
    }

    this.chatStateManager.openSidePanel();
  }
}
