import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelThread extends DiscourseRoute {
  @service router;
  @service chatStateManager;
  @service chat;
  @service chatThreadPane;

  redirectToChannel(channel, transition) {
    transition.abort();
    this.chatStateManager.closeSidePanel();
    this.router.transitionTo("chat.channel", ...channel.routeModels);
  }

  model(params, transition) {
    const channel = this.modelFor("chat.channel");
    return channel.threadsManager
      .find(channel.id, params.threadId)
      .catch(() => {
        this.redirectToChannel(channel, transition);
        return;
      });
  }

  afterModel(thread, transition) {
    const channel = this.modelFor("chat.channel");

    if (!channel.threadingEnabled && !thread.force) {
      this.redirectToChannel(channel, transition);
      return;
    }

    channel.activeThread = thread;
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

  beforeModel() {
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
